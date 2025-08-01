{
  lib,
  fetchFromGitHub,
  python3,
  installShellFiles,
  nix-update-script,
}:

let
  py = python3.override {
    self = py;
    packageOverrides = self: super: {
      jmespath = super.jmespath.overridePythonAttrs (oldAttrs: rec {
        version = "0.10.0";
        src = oldAttrs.src.override {
          inherit version;
          sha256 = "b85d0567b8666149a93172712e68920734333c0ce7e89b78b3e987f71e5ed4f9";
          hash = "";
        };
        doCheck = false;
      });
    };
  };
in

py.pkgs.buildPythonApplication rec {
  pname = "oci-cli";
  version = "3.62.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "oracle";
    repo = "oci-cli";
    tag = "v${version}";
    hash = "sha256-QLvHQwKNS5yr3ZNyQIK2nTgDZ+BKAd0K+H6e63bI4PM=";
  };

  nativeBuildInputs = [ installShellFiles ];

  build-system = with py.pkgs; [
    setuptools
  ];

  dependencies = with py.pkgs; [
    arrow
    certifi
    click
    cryptography
    jmespath
    oci
    prompt-toolkit
    pyopenssl
    python-dateutil
    pytz
    pyyaml
    retrying
    six
    terminaltables
  ];

  pythonRelaxDeps = [
    "click"
    "PyYAML"
    "cryptography"
    "oci"
    "prompt-toolkit"
    "pyOpenSSL"
    "terminaltables"
  ];

  # Propagating dependencies leaks them through $PYTHONPATH which causes issues
  # when used in nix-shell.
  postFixup = ''
    rm $out/nix-support/propagated-build-inputs
  '';

  postInstall = ''
    cat >oci.zsh <<EOF
    #compdef oci
    zmodload -i zsh/parameter
    autoload -U +X bashcompinit && bashcompinit
    if ! (( $+functions[compdef] )) ; then
        autoload -U +X compinit && compinit
    fi

    EOF
    cat src/oci_cli/bin/oci_autocomplete.sh >>oci.zsh

    installShellCompletion \
      --cmd oci \
      --bash src/oci_cli/bin/oci_autocomplete.sh \
      --zsh oci.zsh
  '';

  doCheck = true;

  pythonImportsCheck = [
    "oci_cli"
  ];

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description = "Command Line Interface for Oracle Cloud Infrastructure";
    homepage = "https://docs.cloud.oracle.com/iaas/Content/API/Concepts/cliconcepts.htm";
    license = with licenses; [
      asl20 # or
      upl
    ];
    maintainers = with maintainers; [
      ilian
      FKouhai
    ];
  };
}
