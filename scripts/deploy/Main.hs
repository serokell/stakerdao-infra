{-# LANGUAGE RecordWildCards #-}
import System.Posix.Signals (installHandler, Handler(Catch, Default), sigTERM, sigINT)
import System.Directory (removePathForcibly)
import Options.Applicative (Parser, ParserInfo, option, progDesc, helper, info, execParser, fullDesc, header, metavar, short, help, strOption, argument, switch, showDefault, value, long, auto, (<**>))
import Control.Applicative (optional)
import System.Posix.Temp (mkdtemp)
import Data.Maybe (fromMaybe, fromJust)
import Data.Char (toLower)
import Control.Monad (when, void, liftM2)
import Control.Exception (try, IOException)
import HSH

data Target = Staging | Production | Blend_Demo deriving (Read, Show)

data Deployment = System | Service deriving (Read, Show, Eq)

data Opts
  = Opts
  { prime :: Bool
  , key :: Maybe String
  , repo :: FilePath
  , ref :: String
  , ip :: Maybe String
  , target :: Target
  , deployment :: Deployment
  } deriving (Show)

options :: Parser Opts
options = Opts
  <$> switch (long "prime")
  <*> optional (strOption (long "key" <> short 'k'))
  <*> strOption (long "repo" <> value "ssh://git@github.com/serokell/stakerdao-agora" <> showDefault)
  <*> strOption (long "ref" <> value "mkaito/sdao89-profile-env" <> showDefault)
  <*> optional (strOption (long "ip"))
  <*> argument auto (metavar "TARGET")
  <*> argument auto (metavar "CLOSURE")
optionsInfo :: ParserInfo Opts
optionsInfo = info (options <**> helper) fullDesc

ssh :: Opts -> String
ssh Opts {..} = targetUser <> "@" <> targetIP
  where
    targetUser = if prime then "root" else "buildkite"
    targetIP = fromMaybe
      (case target of
         Staging -> "3.9.146.241"
         Production -> "35.177.67.81"
         Blend_Demo -> "") ip

activationCommand :: Opts -> FilePath -> String
activationCommand Opts {..} path = case deployment of
  System -> if prime
    then "sudo system-activate "<>path
    else path<>"/bin/switch-to-configuration switch"
  Service -> if prime
    then "sudo service-activate /nix/var/nix/profiles/agora "<>path
    else "nix-env --profile /nix/var/nix/profiles/agora --set "<>path<>" && systemctl restart agora"

deploymentAttr :: Opts -> String
deploymentAttr Opts {..} = case deployment of
  System -> toLower <$> show target
  Service -> "deploy"

fetch :: Opts -> IO FilePath
fetch Opts {..} = case deployment of
  Service -> head . lines <$> run ("nix", ["eval", "--raw", "(builtins.fetchGit { url = ''"<>repo<>"''; ref = ''"<>ref<>"''; })"])
  System -> return ".."

build :: Opts -> FilePath -> IO FilePath
build opts repo_path = head . lines <$> run ("nix-build", [repo_path, "-A", deploymentAttr opts])

push :: Opts -> FilePath -> IO ()
push opts@Opts {..} path = do
  when prime $ runIO ("nix", ["sign-paths", "-r", "-k", fromJust key, path])
  runIO ("nix", ["copy", "--substitute-on-destination", "--to", "ssh://"<>ssh opts, path])

activate :: Opts -> FilePath -> IO ()
activate opts@Opts {..} path = runIO ("ssh", [ssh opts, activationCommand opts path])

(>>-) = liftM2 (>>=)
infixl 2 >>-

deploy :: Opts -> IO ()
deploy = fetch >>- build >>- push<>activate >>- deploy'
  where
    deploy' o _ = when (deployment o == System) $ deploy $ o { deployment = Service }

main :: IO ()
main = execParser optionsInfo >>= deploy
