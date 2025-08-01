{
  lib,
  buildPythonPackage,
  fetchFromGitHub,

  # build-system
  pybind11,
  setuptools,

  # dependencies
  numpy,

  # tests
  cirq-core,
  matplotlib,
  networkx,
  pandas,
  pytest-xdist,
  pytestCheckHook,
  scipy,
}:

buildPythonPackage rec {
  pname = "stim";
  version = "1.15.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "quantumlib";
    repo = "Stim";
    tag = "v${version}";
    hash = "sha256-Wls7dJkuV/RXnMizwrYOJOKopWEf1r21FKoKHjmpEQ0=";
  };

  postPatch = ''
    # asked to relax this in https://github.com/quantumlib/Stim/issues/623
    substituteInPlace pyproject.toml \
      --replace-quiet "pybind11~=" "pybind11>="

    # Simple workgroud about https://github.com/networkx/networkx/pull/4829
    # https://github.com/quantumlib/Stim/commit/c0dd0b1c8125b2096cd54b6f72884a459e47fe3e
    substituteInPlace glue/lattice_surgery/stimzx/_zx_graph_solver.py \
      --replace-fail "networkx.testing.assert_graphs_equal" "assert networkx.utils.edges_equal"

    substituteInPlace glue/lattice_surgery/stimzx/_text_diagram_parsing.py \
      --replace-fail "nx.testing.assert_graphs_equal" "assert nx.utils.edges_equal"

    substituteInPlace glue/lattice_surgery/stimzx/_text_diagram_parsing_test.py \
      --replace-fail "nx.testing.assert_graphs_equal" "assert nx.utils.edges_equal"
  '';

  build-system = [
    pybind11
    setuptools
  ];

  dependencies = [ numpy ];

  nativeCheckInputs = [
    cirq-core
    matplotlib
    networkx
    pandas
    pytest-xdist
    pytestCheckHook
    scipy
  ];

  pythonImportsCheck = [ "stim" ];

  enableParallelBuilding = true;

  enabledTestPaths = [
    # From .github/workflows
    "src/"
    "glue/cirq"
  ];

  disabledTests = [
    # AssertionError: Sample rate 1.0 is over 5 standard deviations away from 1.0.
    "test_frame_simulator_sampling_noisy_gates_agrees_with_cirq_data"
    "test_tableau_simulator_sampling_noisy_gates_agrees_with_cirq_data"
  ];

  meta = {
    description = "Tool for high performance simulation and analysis of quantum stabilizer circuits, especially quantum error correction (QEC) circuits";
    mainProgram = "stim";
    homepage = "https://github.com/quantumlib/stim";
    changelog = "https://github.com/quantumlib/Stim/releases/tag/${src.tag}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ chrispattison ];
  };
}
