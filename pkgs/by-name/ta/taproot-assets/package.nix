{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule rec {
  pname = "taproot-assets";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "lightninglabs";
    repo = "taproot-assets";
    rev = "v${version}";
    hash = "sha256-g9YG/qeXM7hmpgvhyTPTOWy37rGG/Tbc5YiuaQFIbJA=";
  };

  vendorHash = "sha256-9d7+y3f+IGDn5wbe9PY58en3cCkWMxCqBBBrRCDDg2U=";

  subPackages = [
    "cmd/tapcli"
    "cmd/tapd"
  ];

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Daemon for the Taproot Assets protocol specification";
    homepage = "https://github.com/lightninglabs/taproot-assets";
    license = licenses.mit;
    maintainers = with maintainers; [ prusnak ];
  };
}
