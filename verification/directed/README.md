# RTL Development Template

## Setup

From the root directory run the following:

### For `bash`

```bash
export GIT_ROOT="$(git rev-parse --show-toplevel)"
export TB_WORK="$GIT_ROOT/work/tb"
export TB_SCRIPTS="$GIT_ROOT/verification/directed/scripts"
mkdir -p "$TB_WORK" && cd "$TB_WORK"
ln -sf $TB_SCRIPTS/makefiles/Makefile.vcs Makefile
ln -sf $TB_SCRIPTS/setup/setup_synopsys_eda.sh
make
```

### For `tcsh`

```bash
setenv GIT_ROOT `git rev-parse --show-toplevel`
setenv TB_WORK $GIT_ROOT/work/tb
setenv TB_SCRIPTS $GIT_ROOT/verification/directed/scripts
mkdir -p $TB_WORK && cd $TB_WORK
ln -sf $TB_SCRIPTS/makefiles/Makefile.vcs Makefile
ln -sf $TB_SCRIPTS/setup/setup_synopsys_eda.tcsh
source setup_synopsys_eda.tcsh
make
```

## Rules

**Use `timeunit 1ns;` and `timeprecision 100ps;` in:**

- Testbench modules
- Interfaces (since they're typically used in testbenches for verification)
- Any simulation-only code with timing constructs

**Skip them in:**

- Synthetizable RTL modules

**You can save your waveform in:**

- `verification/directed/scripts/verdi/`
- Example: `waveform.rc`
