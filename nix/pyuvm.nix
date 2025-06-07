{ buildPythonPackage
, cocotb
, fetchPypi
, lib
, pylint
, pytest
, sphinx
}:
let
  pname = "pyuvm";
  version = "3.0.0";
in
buildPythonPackage {
  inherit pname version;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-RbImY+Gn2e1/vVWkB0q1pfZzqE8fsS4fC85vOwGq7mY=";
  };

  propagatedBuildInputs = [
    cocotb
    pytest
  ];

  propagatedNativeBuildInputs = [
    pylint
    sphinx
  ];

  meta = {
    description = "pyuvm is the Universal Verification Methodology implemented in Python instead of SystemVerilog";
    changelog = "https://github.com/pyuvm/pyuvm/releases/tag/${version}";
    homepage = "https://github.com/pyuvm/pyuvm";
    license = lib.licenses.asl20;
  };
}
