/**
  Module: dev-opts.nix
  Description: HACK!
  This module allows setting impermanence settings in the respective modules
  In the dev enviroment, without impermanence, these values are ignored
*/
{ lib, ... }:
{
  options.environment.persistence = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Stub to allow persistence definitions when impermanence is not loaded.";
  };
}
