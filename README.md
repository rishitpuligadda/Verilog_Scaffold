# Verilog Scaffold

`vscaff` is a command-line tool, written in Tcl, that generates ready-to-edit Verilog design modules and matching testbenches. You can describe a module in a JSON config file and get a fully declared module (parameters, ports, widths) plus a testbench with clock generators, reset sequencing, a DUT instance and signal monitoring. Or you can give it just a file name and get an empty skeleton to start from.

The goal is to skip the repetitive boilerplate of starting a new module so you can go straight to writing logic.

> **Current scope**
> - **Config files:** only **JSON** is supported for now.
> - **Output:** only **Verilog** (Verilog-2001 style) is generated for now. Files may be given a `.sv` extension, but the generated code is plain Verilog.

---

## Table of Contents

- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Installer options](#installer-options)
  - [Running without installing](#running-without-installing)
- [Usage](#usage)
  - [Command-line options](#command-line-options)
  - [Mode 1: File mode (`-file`)](#mode-1-file-mode--file)
  - [Mode 2: Config mode (`-config`)](#mode-2-config-mode--config)
- [The Config File](#the-config-file)
  - [Minimal example](#minimal-example)
  - [Full example](#full-example)
  - [Key reference](#key-reference)
  - [`module`](#module)
  - [`design_path` and `tb_path`](#design_path-and-tb_path)
  - [`parameters`](#parameters)
  - [`clocks`](#clocks)
  - [`ports`](#ports)
  - [Port widths](#port-widths)
  - [Port types](#port-types)
  - [`generate_tb`](#generate_tb)
- [What Gets Generated](#what-gets-generated)
  - [The design file](#the-design-file)
  - [The testbench file](#the-testbench-file)
  - [Complete example output](#complete-example-output)
- [Features in Detail](#features-in-detail)
  - [Automatic clock handling](#automatic-clock-handling)
  - [Reset detection and sequencing](#reset-detection-and-sequencing)
  - [Testbench timing parameters](#testbench-timing-parameters)
  - [Overwrite protection](#overwrite-protection)
  - [Input validation](#input-validation)
  - [Error handling and debugging](#error-handling-and-debugging)
- [Simulating the Output](#simulating-the-output)
- [Project Structure](#project-structure)
- [Current Limitations](#current-limitations)

---

## Quick Start

```bash
git clone https://github.com/<your-username>/verilog_scaffold.git
cd verilog_scaffold
./install.sh                     # installs prerequisites + the "vscaff" command

# Then, from any directory:
vscaff counter                                        # empty design   -> counter.v
vscaff tb_counter                                     # empty testbench -> tb_counter.v
vscaff -config test_files/configs/test2.json          # design + testbench from JSON
```

---

## Requirements

| Requirement | Why | Installed automatically? |
|---|---|---|
| **Tcl 8.6+** (`tclsh`) | Runs the generator | Yes, by `install.sh` |
| **Tcllib** | Provides the `json` package used to read config files | Yes, by `install.sh` |
| `git` | To clone the repository | No |
| *(Optional)* **Icarus Verilog** or any Verilog simulator | To compile and simulate the generated files | No |

You don't need to install Tcl or Tcllib yourself: `install.sh` detects your package manager and installs whatever is missing (see [Installation](#installation)).

For simulation on Ubuntu/Debian:

```bash
sudo apt install iverilog
```

---

## Installation

The repository includes an installer that sets up a `vscaff` command you can run from any directory, so you never need to type the script's full path.

```bash
git clone https://github.com/<your-username>/verilog_scaffold.git
cd verilog_scaffold
./install.sh
```

If you get `Permission denied`, run `bash install.sh` instead, or `chmod +x install.sh` first.

What the installer does:

1. **Checks the prerequisites** (Tcl 8.6 or newer, and Tcllib's `json` package) and **installs any that are missing** using your system's package manager. You'll be asked for your password once, because installing system packages needs administrator rights. If everything is already present, nothing is installed.
2. Copies `src/` to `~/.local/share/verilog_scaffold/`.
3. Creates the command `~/.local/bin/vscaff`, a link to the copied script.
4. Runs `vscaff -h` to confirm the install works.
5. **Adds `~/.local/bin` to your `PATH`** if it isn't there already, so `vscaff` works in every new terminal. It adds a small, clearly marked block to your shell's startup file:

   | Your shell | File edited |
   |---|---|
   | bash (Linux) | `~/.bashrc` |
   | bash (macOS) | `~/.bash_profile` |
   | zsh | `~/.zshrc` |
   | fish | `~/.config/fish/config.fish` |
   | other | `~/.profile` |

   The block is added only once, however many times you run the installer, and it never adds duplicate `PATH` entries. `./install.sh --uninstall` removes it again.

After installing, **open a new terminal** and `vscaff` is ready. To use it in the terminal you installed from, run the `source ...` command the installer prints. (No installer can change the `PATH` of the terminal that started it.)

Supported package managers for step 1:

| System | Package manager | What gets installed |
|---|---|---|
| Ubuntu, Debian, Linux Mint, WSL | `apt` | `tcl`, `tcllib` |
| Fedora, RHEL, Rocky, AlmaLinux | `dnf` / `yum` | `tcl`, `tcllib` |
| Arch, Manjaro | `pacman` | `tcl`, `tcllib` |
| openSUSE | `zypper` | `tcl`, `tcllib` |
| Alpine | `apk` | `tcl`, `tcllib` |
| macOS | Homebrew | `tcl-tk` (includes Tcllib) |

After installing, the installer checks again that Tcl and the `json` package actually work, so you find out immediately if something went wrong. If the packages can't be installed (for example, no administrator access, or an unsupported system), the installer stops and prints the commands to install them yourself.

**What happens without administrator access?** If you can't use `sudo`, ask an administrator to install `tcl` and `tcllib`, then run `./install.sh` again. Alternatively, run `./install.sh --no-deps` to install `vscaff` anyway and sort out the prerequisites later. Without Tcllib, file mode (`vscaff counter`) still works; only `-config` needs it.

Because the files are copied, the command keeps working even if you later move or delete the cloned repository.

### Installer options

| Command | What it does |
|---|---|
| `./install.sh` | Install for your user as `vscaff` |
| `./install.sh --name vgen` | Use a different command name |
| `./install.sh --dev` | Link to the repository instead of copying it. Your edits to `src/` take effect immediately, which is useful while developing the tool. |
| `sudo ./install.sh --prefix /usr/local` | Install for all users (into `/usr/local/bin` and `/usr/local/share`). Personal startup files are not edited; `/usr/local/bin` is normally on `PATH` already. |
| `./install.sh --no-deps` | Don't install missing prerequisites; only check for them and print a warning |
| `./install.sh --no-path` | Don't edit your shell's startup file; add the install directory to `PATH` yourself |
| `./install.sh --uninstall` | Remove the command and the copied files. Pass the same `--name`/`--prefix` you installed with. Also removes the `PATH` block from your startup file. Tcl and Tcllib are left installed, since other programs may use them. |

To **update** after pulling new changes, run `./install.sh` again. (This isn't needed with `--dev`.)

The installer never overwrites a real file: if something that isn't its own link already exists at the target path, it stops with an error.

### Running without installing

You can also run the script directly from the repository, from any directory:

```bash
/path/to/verilog_scaffold/src/generate_verilog.tcl -config my_config.json
tclsh /path/to/verilog_scaffold/src/generate_verilog.tcl counter
```

The script finds its own `lib/` folder automatically, including when it's called through a symlink. In this case, you need to install the prerequisites yourself (for example, `sudo apt install tcl tcllib`).

---

## Usage

```
vscaff [-force] -file <filename>
vscaff [-force] -config <config.json>
```

### Command-line options

| Option | Description |
|---|---|
| `-file <name>` | Generate an empty design or testbench skeleton named `<name>`. The `-file` keyword is optional: a bare name works too. |
| `-config <file.json>` | Generate a fully declared design (and, by default, a testbench) from a JSON config. |
| `-force` | Overwrite output files that already exist. Without it, the tool refuses to overwrite anything. |
| `-debug` | On error, print the full Tcl stack trace instead of a one-line message. |
| `-h`, `-help`, `--help` | Show the help text and exit. |

Rules:

- Use **either** `-file` **or** `-config`, not both.
- Each option may be given only once.
- Unknown options (for example, a typo like `-confg`) are rejected with an error rather than ignored.
- The exit status is `0` on success and `1` on any error, so the tool is safe to use in scripts and Makefiles.

### Mode 1: File mode (`-file`)

File mode creates an **empty skeleton** from nothing but a name. Use it when you want a correctly named, correctly formatted starting file and plan to write everything else yourself.

```bash
vscaff counter              # -> counter.v      (design)
vscaff -file alu.v          # -> alu.v          (design)
vscaff -file rtl/uart       # -> rtl/uart.v     (design, rtl/ created if missing)
vscaff -file tb_counter     # -> tb_counter.v   (testbench for "counter")
vscaff -file counter_tb     # -> counter_tb.v   (testbench for "counter")
vscaff -file fifo.sv        # -> fifo.sv        (Verilog code, .sv extension)
```

How the name is interpreted:

| Name pattern | What is generated |
|---|---|
| `tb_<name>` | Testbench module `tb_<name>`, with a TODO noting the DUT is `<name>` |
| `<name>_tb` | Testbench module `<name>_tb`, with a TODO noting the DUT is `<name>` |
| `tb` | Testbench module `tb` |
| anything else | Design module with that name |

Additional behaviour:

- If no extension is given, `.v` is added.
- Only `.v` and `.sv` extensions are accepted.
- A `.json` file name is rejected with a hint to use `-config` instead. This prevents accidentally overwriting a config file.
- The path is used **as given**, relative to your current directory, and missing parent folders are created.
- The module name must be a legal Verilog identifier and not a reserved keyword (see [Input validation](#input-validation)).

A design skeleton (`vscaff counter`) looks like this:

```verilog
`timescale 1ns / 1ps

module counter;

    // TODO: implement design logic

endmodule
```

A testbench skeleton (`vscaff tb_counter`) looks like this:

```verilog
`timescale 1ns / 1ps

module tb_counter;

    // TODO: declare signals and instantiate counter

    initial begin
        #100 $finish;
    end

endmodule
```

### Mode 2: Config mode (`-config`)

Config mode reads a JSON file that describes the module and generates:

1. **A design file** with the full module header: parameters, every port with its direction, type and width, all neatly aligned.
2. **A testbench file** (unless disabled) with signals declared, clocks generated, the DUT instantiated, resets sequenced, and outputs monitored.

```bash
cd verilog_scaffold
vscaff -config test_files/configs/test2.json
```

```
Generated design:    /home/you/verilog_scaffold/test_files/verilog/dual_clock_fifo.v
Generated testbench: /home/you/verilog_scaffold/test_files/verilog/tb_dual_clock_fifo.v
```

The format of the config file is described in the next section.

---

## The Config File

Config files must be **JSON** (with a `.json` extension). This is currently the only supported config format.

### Minimal example

Only `module` is required:

```json
{
  "module": "my_block"
}
```

This produces `my_block.v` (a module with no ports) and `tb_my_block.v` in the current directory.

### Full example

This is `test_files/configs/test2.json`, which uses every major feature:

```json
{
  "module": "dual_clock_fifo",
  "path": "../verilog",
  "clocks": {
    "wr_clk": 10,
    "rd_clk": 25
  },
  "parameters": {
    "DATA_WIDTH": 32,
    "DEPTH": 16
  },
  "ports": {
    "inputs": [
      "wr_rst_n",
      "wr_en",
      { "name": "wr_data", "width": "DATA_WIDTH" },
      "rd_rst_n",
      "rd_en"
    ],
    "outputs": [
      { "name": "rd_data", "width": "DATA_WIDTH", "type": "reg" },
      "full",
      "empty"
    ]
  }
}
```

### Key reference

| Key | Required | Type | Default | Description |
|---|---|---|---|---|
| `module` | **yes** | string | n/a | Name of the module to generate |
| `design_path` | no | string | current directory | Where to write the design: a directory or a `.v`/`.sv` file path |
| `path` | no | string | n/a | Alias for `design_path`, kept for older configs |
| `tb_path` | no | string | same directory as the design | Where to write the testbench: a directory or a `.v`/`.sv` file path |
| `parameters` | no | object | none | Module parameters and their default values |
| `clocks` | no | object | auto-detect | Clock names and their periods in ns |
| `clk_period` | no | number | n/a | Legacy shorthand: one clock named `clk` with this period |
| `ports` | no | object | none | Contains `inputs` and/or `outputs` arrays |
| `ports.inputs` | no | array | none | Input ports |
| `ports.outputs` | no | array | none | Output ports |
| `generate_tb` | no | boolean | `true` | Whether to generate a testbench |
| `tb` | no | boolean | `true` | Alias for `generate_tb` (`generate_tb` wins if both are set) |

Each key is explained in detail below.

### `module`

The name of the generated module. It must be a legal Verilog identifier and not a reserved keyword.

If the value contains a directory or an extension, they are stripped: `"rtl/alu.v"` becomes module `alu`. Use [`design_path` and `tb_path`](#design_path-and-tb_path) to control where files are written.

### `design_path` and `tb_path`

These two keys control where the design and the testbench are written. Each can be either of the following:

- **A directory**, such as `"../rtl"`. A default file name is used inside it.
- **A file path ending in `.v` or `.sv`**, such as `"../sim/fifo_tb.v"`. The file is written to exactly that path.

| Key | If it's a directory | If it's a file path | If omitted |
|---|---|---|---|
| `design_path` | `<directory>/<module>.v` | Exactly that file | `<module>.v` in your current directory |
| `tb_path` | `<directory>/tb_<module>` + the design's extension | Exactly that file | In the same directory as the design |

`path` is still accepted as an alias for `design_path`, so older configs keep working. Setting both `path` and `design_path` is an error.

Keeping design and testbench files apart, a common layout, looks like this:

```json
{
  "module": "uart_tx",
  "design_path": "../rtl",
  "tb_path": "../sim"
}
```

If this config is saved in `test_files/configs/`, it writes `test_files/rtl/uart_tx.v` and `test_files/sim/tb_uart_tx.v`.

**Testbench module name.** By default the testbench module is named `tb_<module>`. If `tb_path` names a file, the file name becomes the module name instead, so the module always matches its file. For example, `"tb_path": "../sim/uart_tx_tb.v"` creates `module uart_tx_tb;`. That name must be a legal Verilog identifier and must differ from the design module's name.

**Extensions.** When `tb_path` is a directory (or omitted), the testbench uses the same extension as the design, so a `.sv` design gets a `.sv` testbench.

If the testbench is disabled with `"generate_tb": false`, `tb_path` is ignored and a note is printed.

**How paths are resolved.** This applies to both keys:

| Value | Resolved against |
|---|---|
| Relative, e.g. `"../rtl"` | The **directory containing the config file**, **not** your current directory |
| Absolute, e.g. `"/home/you/rtl"` | Used as-is |

This means a config always writes to the same place, no matter which directory you run the tool from. For example, `test_files/configs/test2.json` uses `"path": "../verilog"`, which always means `test_files/verilog/`. All of these commands produce the same output:

```bash
vscaff -config test_files/configs/test2.json                      # from the repository root
vscaff -config ../test_files/configs/test2.json                   # from src/
vscaff -config ~/verilog_scaffold/test_files/configs/test2.json   # from any other directory
```

Missing directories are created automatically. The full resolved paths are printed after generation.

### `parameters`

A JSON object mapping parameter names to default values:

```json
"parameters": {
  "DATA_WIDTH": 32,
  "DEPTH": 16,
  "INIT_VALUE": "8'hFF"
}
```

- Each name must be a legal Verilog identifier.
- Values are written into the Verilog **exactly as given**, so you can use Verilog literals as strings (`"8'hFF"`, `"4'b1010"`).
- Empty values are rejected.
- Order is preserved in the generated module.
- Parameters can be used as port widths (see [Port widths](#port-widths)).
- The testbench redeclares every parameter and passes it to the DUT, so changing a value in the testbench propagates to the design.

### `clocks`

A JSON object mapping clock names to their **period in nanoseconds**:

```json
"clocks": {
  "wr_clk": 10,
  "rd_clk": 25
}
```

- Periods must be positive numbers. Decimals are allowed (for example, `12.5`). Strings like `"10ns"` are rejected.
- Each clock is automatically added as a **1-bit input**, placed at the **top** of the port list. You don't need to list clocks in `ports.inputs`. If you do list one there, it isn't duplicated, but it must be 1 bit wide.
- A clock cannot also be declared as an output.
- The testbench gets one clock generator per clock (see [Automatic clock handling](#automatic-clock-handling)).

**Legacy form:** `"clk_period": 10` is equivalent to `"clocks": { "clk": 10 }`.

**No clocks given?** Clock-like inputs are detected automatically (see [Automatic clock handling](#automatic-clock-handling)).

### `ports`

```json
"ports": {
  "inputs":  [ ... ],
  "outputs": [ ... ]
}
```

Each entry in `inputs` or `outputs` can be written in one of two forms.

**1. A plain string** creates a 1-bit port with the default type:

```json
"wr_en"
```

**2. An object** lets you set the width and/or type:

```json
{ "name": "rd_data", "width": "DATA_WIDTH", "type": "reg" }
```

| Field | Required | Description |
|---|---|---|
| `name` | **yes** | Port name (a legal Verilog identifier) |
| `width` | no | Bus width (see [Port widths](#port-widths)). Omit for 1 bit. |
| `type` | no | Net type (see [Port types](#port-types)). Omit for the default. |

Every port name must be unique across inputs, outputs and clocks.

In the generated design, ports appear in this order: clocks first, then inputs (in the order you listed them), then outputs (in the order you listed them).

### Port widths

The `width` field accepts several forms:

| `width` value | Generated range | Notes |
|---|---|---|
| *(omitted)*, `1` or `""` | *(none)* | 1-bit scalar |
| `8` | `[7:0]` | Integer N becomes `[N-1:0]`. Must be at least 1. |
| `"DATA_WIDTH"` | `[DATA_WIDTH-1:0]` | Must be a name defined in `parameters` |
| `"15:8"` or `"[15:8]"` | `[15:8]` | Explicit range, used as-is |
| `"DATA_WIDTH*2"` | `[(DATA_WIDTH*2)-1:0]` | Any other expression, wrapped in parentheses |

Expressions are wrapped in parentheses so that `-1` applies to the whole expression. For example, `"A<<1"` becomes `[(A<<1)-1:0]`. Without the parentheses it would be `[A<<1-1:0]`, which Verilog evaluates as `A<<0`.

### Port types

| Direction | Allowed `type` values | Default |
|---|---|---|
| Input | `wire` | *(none, which is implicitly a wire)* |
| Output | `wire`, `reg` | *(none, which is implicitly a wire)* |

Use `"type": "reg"` on outputs you'll drive from an `always` block. `input reg` is not legal Verilog, so it is rejected. Type names are case-insensitive.

### `generate_tb`

```json
"generate_tb": false
```

Set this to `false` to generate only the design file. It defaults to `true`. `tb` is accepted as an alias, and if both are present, `generate_tb` takes priority. The value must be a boolean; anything else, such as `"maybe"`, is rejected.

---

## What Gets Generated

### The design file

The design file contains:

- `` `timescale 1ns / 1ps ``
- The module header with:
  - a `#( ... )` parameter list, if parameters were given;
  - the port list: clocks, then inputs, then outputs, with direction, type, width and name aligned in columns.
- A `// TODO: implement design logic` placeholder where your code goes.
- `endmodule`

The design body is intentionally left empty. The tool generates the interface; you write the logic.

### The testbench file

The testbench is named `tb_<module>` (or after the file name given in `tb_path`) and contains, in order:

| Section | Contents |
|---|---|
| Timescale | `` `timescale 1ns / 1ps ``, matching the design |
| Parameters | Every design parameter, one `<CLOCK>_PERIOD` per clock, plus `RESET_TIME` and `SIM_TIME` |
| Signals | A `reg` for every DUT input and a `wire` for every DUT output, with matching widths |
| Clock generators | `always #(<CLOCK>_PERIOD / 2.0) clk = ~clk;` for each clock |
| DUT instance | The module instantiated as `dut`, with every parameter and port connected by name |
| Stimulus | An `initial` block that initialises every input, starts monitoring, releases resets, leaves a TODO for your stimulus, and calls `$finish` |

Inside the `initial` block:

1. All clocks are set to `1'b0`.
2. All reset inputs are set to their **asserted** level, and every other input is set to `0`, so nothing starts as `X`.
3. `$timeformat` is set so that times print in ns.
4. `$monitor` prints the simulation time and every non-clock port (in hex) whenever any of them changes.
5. After `RESET_TIME`, all resets are **released**.
6. A `// TODO: add test stimulus here` marks where your test sequence goes.
7. After `SIM_TIME`, the simulation ends with `$finish`.

### Complete example output

Running `vscaff -config test_files/configs/test2.json` on the [full example](#full-example) produces the following two files.

<details>
<summary><b>dual_clock_fifo.v</b></summary>

```verilog
`timescale 1ns / 1ps

module dual_clock_fifo #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 16
) (
    input                       wr_clk,
    input                       rd_clk,
    input                       wr_rst_n,
    input                       wr_en,
    input      [DATA_WIDTH-1:0] wr_data,
    input                       rd_rst_n,
    input                       rd_en,
    output reg [DATA_WIDTH-1:0] rd_data,
    output                      full,
    output                      empty
);

    // TODO: implement design logic

endmodule
```

</details>

<details>
<summary><b>tb_dual_clock_fifo.v</b></summary>

```verilog
`timescale 1ns / 1ps

module tb_dual_clock_fifo;

    // Parameters
    parameter DATA_WIDTH    = 32;
    parameter DEPTH         = 16;
    parameter WR_CLK_PERIOD = 10;
    parameter RD_CLK_PERIOD = 25;
    parameter RESET_TIME    = 125;
    parameter SIM_TIME      = 2500;

    // DUT inputs (driven by the TB)
    reg                   wr_clk;
    reg                   rd_clk;
    reg                   wr_rst_n;
    reg                   wr_en;
    reg  [DATA_WIDTH-1:0] wr_data;
    reg                   rd_rst_n;
    reg                   rd_en;

    // DUT outputs (observed by the TB)
    wire [DATA_WIDTH-1:0] rd_data;
    wire                  full;
    wire                  empty;

    // Clock generators
    always #(WR_CLK_PERIOD / 2.0) wr_clk = ~wr_clk;
    always #(RD_CLK_PERIOD / 2.0) rd_clk = ~rd_clk;

    // DUT instantiation
    dual_clock_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .DEPTH      (DEPTH)
    ) dut (
        .wr_clk   (wr_clk),
        .rd_clk   (rd_clk),
        .wr_rst_n (wr_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .rd_rst_n (rd_rst_n),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .full     (full),
        .empty    (empty)
    );

    // Stimulus and monitoring
    initial begin
        wr_clk   = 1'b0;
        rd_clk   = 1'b0;
        wr_rst_n = 1'b0;   // reset asserted
        wr_en    = 0;
        wr_data  = 0;
        rd_rst_n = 1'b0;   // reset asserted
        rd_en    = 0;

        $timeformat(-9, 1, " ns", 0);
        $monitor("time=%0t | wr_rst_n=%0h wr_en=%0h wr_data=%0h rd_rst_n=%0h rd_en=%0h rd_data=%0h full=%0h empty=%0h", $time, wr_rst_n, wr_en, wr_data, rd_rst_n, rd_en, rd_data, full, empty);

        // Release reset(s)
        #(RESET_TIME);
        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        // TODO: add test stimulus here

        #(SIM_TIME) $finish;
    end

endmodule
```

</details>

Both files compile and simulate as generated with Icarus Verilog.

---

## Features in Detail

### Automatic clock handling

**Declared clocks** (via `clocks` or `clk_period`):

- Each is added as a 1-bit input at the top of the design's port list.
- Each gets a period parameter in the testbench, named `<CLOCK NAME IN UPPERCASE>_PERIOD`. For example, `wr_clk` becomes `WR_CLK_PERIOD` and `clk` becomes `CLK_PERIOD`.
- Each gets its own clock generator, toggling every half period. Different clocks run independently, which makes multi-clock designs like dual-clock FIFOs straightforward to set up.
- Clocks are initialised to 0 and are left out of the `$monitor` output to keep it readable.

**Auto-detected clocks**: if the config has **no** `clocks` or `clk_period` key, the tool looks through the inputs for 1-bit ports whose names look like clocks:

| Treated as a clock | Not treated as a clock |
|---|---|
| `clk`, `clk2`, `clock` | `clk_en` |
| `wr_clk`, `sys_clk`, `sys_clock`, `core_clk1` | `clk_sel`, `clk_div` |

Each detected clock gets a default period of **10 ns**, and a note is printed:

```
Note: treating input 'sys_clk' as a 10 ns clock (set "clocks" to change)
```

To use a different period, or to name clocks that don't match this pattern, list them explicitly under `clocks`.

### Reset detection and sequencing

The testbench recognises reset inputs by name and drives them correctly. A name counts as a reset if it contains `rst`, `arst` or `reset` at the start of the name or right after an underscore. This means `first_en` is **not** treated as a reset.

| Reset kind | Example names | Initial value | After `RESET_TIME` |
|---|---|---|---|
| Active-low | `rst_n`, `rstn`, `reset_n`, `reset_b`, `wr_rst_n`, `arst_n` | `1'b0` (asserted) | `1'b1` (released) |
| Active-high | `rst`, `reset`, `sys_rst`, `arst` | `1'b1` (asserted) | `1'b0` (released) |

A reset is treated as active-low when the `rst`/`reset` part is followed by `n` or `b` (optionally after an underscore). If the design has no reset inputs, the release step is simply left out.

### Testbench timing parameters

All timing is expressed as named parameters, so you can tune it in one place:

| Parameter | Value | Meaning |
|---|---|---|
| `<CLOCK>_PERIOD` | from `clocks` | Clock period in ns |
| `RESET_TIME` | 5 × slowest clock period (50 if there are no clocks) | How long resets are held |
| `SIM_TIME` | 100 × slowest clock period (1000 if there are no clocks) | How long to run after the reset release |

Delays in the `initial` block run one after another, so the simulation ends at `RESET_TIME + SIM_TIME` when there are resets, or at `SIM_TIME` when there are none. For the example above, that is 125 + 2500 = 2625 ns.

The testbench parameter names must not clash with your design parameters. For example, a design parameter called `SIM_TIME` or `CLK_PERIOD` (when you also have a clock named `clk`) is reported as an error.

### Overwrite protection

The tool **never overwrites an existing file** unless you pass `-force`:

```
ERROR: '/home/you/verilog_scaffold/test_files/verilog/dual_clock_fifo.v' already exists (use -force to overwrite)
```

This protects modules you've already started writing logic in. In config mode, **all** output paths are checked **before anything is written**. If the testbench already exists, the design isn't written either, so a run never leaves you with a mismatched half-update.

```bash
vscaff -force -config test_files/configs/test2.json
```

### Input validation

Everything is checked before any file is written, so the tool fails early with a clear message instead of producing Verilog that won't compile.

**Names.** Module, port, parameter and clock names must:

- start with a letter or underscore;
- contain only letters, digits, `_` or `$`;
- not be a Verilog reserved keyword (`module`, `input`, `wire`, `reg`, `begin`, and so on, plus common SystemVerilog types like `logic` and `bit`).

**Config checks:**

| Problem | Example error |
|---|---|
| Tcllib not installed | `the Tcl 'json' package (part of Tcllib) is not installed. ...` |
| File missing or unreadable | `configuration file 'x.json' not found or not readable` |
| Not a `.json` file | `unsupported config format '.yaml' (expected .json)` |
| Malformed JSON | `invalid JSON in 'c.json': unexpected token "END" at position 8; expecting OBJECT` |
| No `module` key | `'c.json' has no "module" key` |
| Invalid name | `invalid module name 'my-counter': must start with a letter or underscore and contain only letters, digits, _ or $` |
| Reserved keyword | `invalid module name 'module': it is a reserved Verilog keyword` |
| Duplicate port | `port 'a' is declared more than once` |
| `input reg` | `input 'x': type 'reg' is not allowed (allowed: wire)` |
| Width of 0 or less | `port 'd': width must be at least 1, got 0` |
| Undefined width parameter | `port 'd': width 'WIDTH' is not defined in "parameters"` |
| Bad clock period | `clock 'clk': period must be a positive number, got '10ns'` |
| Clock declared as an output | `clock 'clk' is declared as an output` |
| Multi-bit clock | `clock 'clk' must be 1 bit wide` |
| Empty parameter value | `parameter 'DEPTH' has an empty value` |
| Non-boolean flag | `"generate_tb" must be true or false, got 'maybe'` |
| Malformed port entry | `invalid input port entry: ...` |
| Both `path` and `design_path` set | `use either "design_path" or "path", not both` |
| Testbench file named like the design | `testbench module name 'uart_tx' is the same as the design module name` |
| Invalid testbench file name | `invalid testbench module name 'my-tb': ...` |
| Design and testbench on the same file | `design and testbench would both be written to '...'` |

**File mode checks:** invalid or reserved module names, unsupported extensions, and `.json` file names (with a hint to use `-config`).

### Error handling and debugging

Errors are printed as a single readable line, and the tool exits with status `1`:

```
ERROR: port 'd': width 'WIDTH' is not defined in "parameters"
(run again with -debug for the full stack trace)
```

If you're working on the tool itself and need to see exactly where something failed, add `-debug` to print the full Tcl stack trace instead.

---

## Simulating the Output

With Icarus Verilog:

```bash
cd test_files/verilog
iverilog -o sim dual_clock_fifo.v tb_dual_clock_fifo.v
vvp sim
```

Example output (with the design body still empty):

```
time=0.0 ns | wr_rst_n=0 wr_en=0 wr_data=0 rd_rst_n=0 rd_en=0 rd_data=xxxxxxxx full=z empty=z
time=125.0 ns | wr_rst_n=1 wr_en=0 wr_data=0 rd_rst_n=1 rd_en=0 rd_data=xxxxxxxx full=z empty=z
tb_dual_clock_fifo.v:68: $finish called at 2625000 (1ps)
```

The `x` and `z` values on the outputs are expected at this stage, because the design doesn't drive anything yet. They change once you implement the logic.

---

## Project Structure

```
verilog_scaffold/
├── install.sh                   # Installs the vscaff command (see Installation)
├── src/
│   ├── generate_verilog.tcl     # Entry point: argument parsing, library loading, error handling
│   └── lib/
│       ├── utils.tcl            # Shared helpers: name validation, alignment, safe file writing
│       ├── file_flag.tcl        # -file mode: name-based skeleton generation
│       ├── config_flag.tcl      # -config mode: JSON parsing, validation, port normalisation
│       ├── design_tpl.tcl       # Design module template
│       └── tb_tpl.tcl           # Testbench template
└── test_files/
    ├── configs/                 # Example JSON configs
    └── verilog/                 # Example generated output
```

How the pieces fit together:

1. `generate_verilog.tcl` parses the command line, loads the libraries in `lib/`, and calls either `file_flag` or `config_flag`.
2. `config_flag` reads and validates the JSON, then converts every port into a uniform `{type width name}` form.
3. `design_tpl.tcl` and `tb_tpl.tcl` turn that description into Verilog text.
4. `utils.tcl` checks that the output paths are safe to write, then writes the files.

---

## Current Limitations

- **JSON only.** Configs must be JSON. Other formats (YAML, TOML, etc.) are not supported yet.
- **Verilog only.** Output is Verilog-2001 style. `.sv` file names are accepted, but no SystemVerilog constructs (`logic`, interfaces, `always_ff`, etc.) are generated, and VHDL is not supported.
- **No `inout` ports.** Only `inputs` and `outputs` are supported.
- **No `signed` ports**, and no packed arrays or multi-dimensional ports.
- **The design body is empty.** The tool generates the module interface only; you write the logic.
- **Testbench stimulus is a placeholder.** The testbench sets up clocks, resets, the DUT and monitoring, but the actual test sequence is left for you to write.
- **Fixed timescale.** All files use `` `timescale 1ns / 1ps ``, and clock periods are always in ns.
- **Name-based detection.** Auto-detected clocks and resets depend on naming conventions. Declare clocks explicitly under `clocks` if your names don't follow these patterns.
