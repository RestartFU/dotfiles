final: prev:
let
  version = "1.7.6-qt6";
in
{
  mcpelauncher-client = prev.mcpelauncher-client.overrideAttrs (old: {
    inherit version;
    src = final.fetchFromGitHub {
      owner = "minecraft-linux";
      repo = "mcpelauncher-manifest";
      tag = "v${version}";
      fetchSubmodules = true;
      hash = "sha256-KAHAr1cAkG6B15CTwxRWZWT9IdTcvCSal3jrPe8C4wE=";
    };
    patches = [
      ./mcpelauncher-client-1.7.6-glfw.patch
      (final.lib.last old.patches)
    ];
  });

  mcpelauncher-ui-qt =
    (prev.mcpelauncher-ui-qt.override {
      mcpelauncher-client = final.mcpelauncher-client;
    }).overrideAttrs (_old: {
      inherit version;
      src = final.fetchFromGitHub {
        owner = "minecraft-linux";
        repo = "mcpelauncher-ui-manifest";
        tag = "v${version}";
        fetchSubmodules = true;
        hash = "sha256-Oibi7+LJK7K1a1fFN2SKy4XiA0gSC4u7Wmk0t86SHaw=";
      };
    });
}
