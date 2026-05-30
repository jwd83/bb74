# Game Design Document: **The Infinite Breadboard**

## 1\. High Concept

**The Infinite Breadboard** is a digital logic construction game where players begin with basic 74-series logic components and progressively build increasingly complex circuits, eventually creating custom chips, CPUs, memory systems, peripherals, and complete computers.

The central fantasy is:

Start with NAND gates. End with your own computer architecture.

Players construct circuits on an infinite breadboard-like workspace using realistic digital components inspired by TTL logic. Once a circuit is tested and proven correct, the player can synthesize it into a reusable custom chip. These custom chips become part of the player’s personal component library and can be used to build larger, more advanced systems.

The game combines the physical satisfaction of breadboard wiring, the puzzle-solving of digital logic, and the long-term creative progression of building a complete computer from first principles.

---

## 2\. Genre and Target Audience

### Genre

* Logic simulation game

* Engineering sandbox

* Puzzle/automation game

* Educational construction game

* Zachtronics-style systems design game

### Target Audience

The game is designed for players interested in:

* Digital logic

* Retro computing

* CPU design

* Electronics

* Zachtronics games

* Turing Complete-style progression

* Minecraft redstone

* FPGA/Verilog concepts

* Building complex systems from simple primitives

The game should be approachable enough for curious beginners but deep enough to support advanced players building full custom architectures.

---

## 3\. Design Pillars

### 3.1 Build from First Principles

Every advanced system should be derivable from simpler components. Players should feel that they personally constructed their computer from the ground up.

A CPU should not appear as a prebuilt object. It should emerge from gates, adders, registers, multiplexers, counters, control logic, buses, memory, and I/O.

---

### 3.2 Abstraction as Reward

The player’s primary reward is the ability to compress working circuits into reusable chips.

Synthesis is not merely a convenience feature. It is the main progression mechanic.

The player builds a half adder, synthesizes it, uses it to build a full adder, synthesizes that, uses it to build a 4-bit adder, then an ALU, then a CPU datapath.

---

### 3.3 Physical Feel, Digital Rules

The game should feel like working with real breadboards, DIP chips, jumper wires, clocks, LEDs, and logic probes.

However, the simulation should remain digital and readable. The goal is not full analog electronics simulation. The game should avoid unnecessary SPICE-level complexity unless added later as an optional expert mode.

---

### 3.4 Debugging is Gameplay

Players should spend meaningful time inspecting signals, stepping clocks, finding bus conflicts, tracing unknown states, and proving that their circuits meet a specification.

Debugging should feel satisfying rather than punishing.

---

### 3.5 Player-Owned Components

Custom chips should feel like personal inventions.

When a player synthesizes a circuit, they choose the chip name, pin layout, package style, label, and visual identity. The game should reinforce that these are the player’s own components, not generic upgrades.

---

## 4\. Core Gameplay Loop

The main loop is:

1. **Receive a goal or decide on a design**

   * Example: build a half adder, register, counter, ALU, or CPU instruction decoder.

2. **Place components**

   * Use standard chips, wires, inputs, clocks, LEDs, and probes.

3. **Wire the circuit**

   * Connect pins using jumper wires, bus ribbons, labels, or board traces.

4. **Test behavior**

   * Use manual inputs, truth table tests, logic probes, timing diagrams, and automated test benches.

5. **Debug**

   * Identify incorrect outputs, floating inputs, bus contention, timing issues, and invalid logic states.

6. **Validate**

   * Pass formal tests or user-defined assertions.

7. **Synthesize**

   * Package the working circuit into a custom chip.

8. **Reuse**

   * Use the new chip as a component in larger designs.

9. **Scale**

   * Build larger subsystems, eventually forming a complete computer.

---

## 5\. Core Mechanics

## 5.1 Infinite Breadboard Workspace

The primary play space is an infinite or very large grid-based workbench.

Players can place:

* Breadboard strips

* DIP logic chips

* Jumper wires

* Buses

* Power rails

* Clocks

* Buttons

* Switches

* LEDs

* Logic probes

* Labels

* Test fixtures

* Custom synthesized chips

The board should support:

* Zooming

* Panning

* Region bookmarks

* Net highlighting

* Wire color coding

* Copy/paste

* Blueprint/ghost placement

* Named circuit regions

* Search by chip name, net name, or label

The workspace should feel physical, but it should not force tedious real-world limitations too early.

---

## 5.2 Components

### Starting Components

The initial component set should be small:

* Power source

* Ground

* Wire

* Button

* Toggle switch

* Clock

* LED

* Logic probe

* 7400 NAND

* 7404 NOT

* 7408 AND

* 7432 OR

* 7486 XOR

### Intermediate Components

Unlocked as the player progresses:

* NOR gates

* Buffers

* Tri-state buffers

* D latches

* D flip-flops

* JK flip-flops

* Multiplexers

* Decoders

* Encoders

* Adders

* Counters

* Shift registers

* Comparators

* Bus transceivers

* SRAM

* ROM

* EEPROM-like program memory

### Advanced Components

Later components may include:

* Memory-mapped display

* Keyboard input

* Terminal output

* UART-like serial peripheral

* Video timing generator

* Simple sound generator

* Stack memory

* Interrupt controller

* DMA-like controller

* Microcode ROM

* Assembler/program loader

---

## 5.3 Signals

The digital simulation should support at minimum:

* 0 — logic low

* 1 — logic high

* Z — high impedance / undriven

* X — unknown, invalid, or conflicting state

Optional advanced signal states:

* rising edge

* falling edge

* oscillating

* metastable warning

* delayed transition

The X state is important for debugging. It should appear when:

* Two outputs drive the same bus with conflicting values

* An input is floating

* A feedback loop has no stable solution

* A circuit oscillates too quickly

* A chip is used incorrectly

* Clocked logic violates setup/hold assumptions in advanced mode

---

## 5.4 Wiring

The wiring system should prioritize readability.

Players can create:

* Individual jumper wires

* Bundled buses

* Net labels

* Named connections

* Color-coded signal groups

* Ribbon cables

* Board-to-board connectors

Wires should be easy to trace. Clicking a wire or pin should highlight the entire connected net.

Potential wire display modes:

* Physical mode: shows exact jumper paths

* Logical mode: shows clean net connections

* Bus mode: collapses related wires into labeled bundles

* Debug mode: colors wires by signal state

---

## 5.5 Chip Synthesis

Chip synthesis is the defining feature of the game.

A player can select a working circuit and package it into a custom reusable chip.

### Synthesis Requirements

Before synthesis, the player must define:

* Chip name

* Input pins

* Output pins

* Bidirectional pins, if allowed

* Clock pins

* Reset pins, if needed

* Power and ground pins, optional depending on game abstraction

* Package type

* Pin layout

* Symbol/icon

* Description

* Test requirements

### Example

A player builds a full adder and synthesizes it into:

JDB\_FULL\_ADDER  
Inputs: A, B, Cin  
Outputs: Sum, Cout  
Package: DIP-8  
Delay: 2 ticks

The chip then appears in the player’s parts drawer.

### Internal Preservation

Synthesized chips should preserve their internal design.

The player can right-click a chip and select:

Open Internals

This opens the original circuit used to create the chip.

This creates a recursive hierarchy:

Computer  
  → CPU  
    → ALU  
      → 8-bit adder  
        → full adder  
          → half adder  
            → NAND gates

This is essential to the identity of the game.

---

## 5.6 Testing and Validation

The game should include strong testing tools.

### Manual Testing

Players can interact with:

* Buttons

* Switches

* Clock stepping

* LEDs

* Logic probes

* Bus inspectors

### Automated Testing

Players can attach test benches to circuits.

A test bench can define:

* Inputs

* Expected outputs

* Clock cycles

* Timing expectations

* Edge-triggered behavior

* Bus states

* Reset conditions

Example output:

Test 6 failed:  
A=1, B=1, Cin=0

Expected:  
Sum=0, Cout=1

Received:  
Sum=1, Cout=0

### Truth Table Generator

For combinational circuits, the game can generate or verify a truth table.

Useful for:

* Gates

* Adders

* Comparators

* Decoders

* Multiplexers

* ALU operations

### Timing Diagram Viewer

For sequential circuits, the game should display signal history over time.

Useful for:

* Flip-flops

* Registers

* Counters

* CPU cycles

* Memory reads/writes

* Bus timing

---

## 5.7 Simulation Speed and Hierarchy

The simulation should support both detailed and abstracted operation.

### Raw Circuit Simulation

Used while editing and debugging.

Components are simulated as nodes in a graph. Wires form nets. Each tick resolves signal states based on component behavior.

### Compiled Chip Simulation

Once synthesized, a chip can be represented more efficiently.

Possible compiled forms:

* Truth table for small combinational logic

* Boolean expression network

* Gate-level netlist

* State machine for sequential circuits

* Cached simulation graph

* Compiled JavaScript or WebAssembly function in later versions

### Hierarchical Simulation

Large systems should not always be flattened to individual gates.

A CPU built from custom chips should simulate mostly at the chip level, while still allowing the player to inspect internals when needed.

This allows large designs to remain performant while preserving the “built from scratch” fantasy.

---

## 6\. Progression

## 6.1 Campaign Structure

The campaign teaches digital systems through escalating goals.

### Era 1: Basic Logic

Goals:

* Build NOT from NAND

* Build AND from NAND

* Build OR from NAND

* Build XOR

* Build a half adder

* Build a full adder

* Build a 4-bit adder

Core lessons:

* Boolean logic

* Truth tables

* Combinational circuits

* Reusable components

---

### Era 2: State and Memory

Goals:

* Build SR latch

* Build D latch

* Build D flip-flop

* Build 4-bit register

* Build counter

* Build shift register

* Build program counter

Core lessons:

* State

* Clocks

* Edges

* Feedback

* Sequential circuits

---

### Era 3: Datapath

Goals:

* Build register file

* Build shared bus

* Build tri-state output control

* Build ALU

* Build flags register

* Build instruction register

* Build memory address register

Core lessons:

* CPU datapath

* Bus architecture

* Register transfer

* ALU operations

* Status flags

---

### Era 4: Control Logic

Goals:

* Build instruction decoder

* Build microstep counter

* Build control signal ROM

* Build fetch/decode/execute cycle

* Execute simple instructions

* Add jumps and branches

Core lessons:

* Control signals

* Instruction execution

* Microcode

* State machines

* Program flow

---

### Era 5: Complete Computer

Goals:

* Add RAM

* Add ROM

* Add memory-mapped I/O

* Add terminal output

* Add keyboard input

* Add simple assembler

* Run a program

* Run a tiny game or demo

Core lessons:

* Complete computer architecture

* I/O

* Software/hardware boundary

* Instruction sets

* Programming custom CPUs

---

## 6.2 Sandbox Mode

Sandbox mode allows free building without campaign restrictions.

Features:

* Unlimited workspace

* Full component library

* Custom chip creation

* Custom test benches

* Save/load projects

* Import/export custom chips

* Shareable circuits

* Challenge creation

* Optional constraints

Possible constraints:

* Minimum chip count

* Minimum delay

* Lowest power score

* Smallest board area

* Fewest wires

* Realistic 74-series-only build

* NAND-only build

* No synthesized chips

---

## 7\. Player Goals

### Short-Term Goals

* Make a light turn on

* Build a gate

* Pass a truth table

* Fix a broken circuit

* Package a simple chip

### Medium-Term Goals

* Build arithmetic circuits

* Build registers

* Build counters

* Create reusable libraries

* Build an ALU

* Build memory access logic

### Long-Term Goals

* Build a CPU

* Design an instruction set

* Build a full computer

* Write programs for that computer

* Share the computer with others

* Optimize and redesign architectures

---

## 8\. User Interface

## 8.1 Main Screen

The main screen consists of:

* Infinite breadboard workspace

* Component drawer

* Wiring tools

* Simulation controls

* Signal inspector

* Project hierarchy panel

* Test results panel

* Minimap or region navigator

### Core Controls

* Run simulation

* Pause simulation

* Step tick

* Step clock cycle

* Reset circuit

* Highlight selected net

* Open test bench

* Open timing diagram

* Synthesize selection

* Open chip internals

---

## 8.2 Parts Drawer

The parts drawer contains:

* Standard components

* User-created chips

* Recently used parts

* Favorite parts

* Search bar

* Filter by category

Categories:

* Gates

* Flip-flops

* Mux/decoder

* Arithmetic

* Memory

* I/O

* Custom chips

* Debug tools

* Power/clock

---

## 8.3 Chip Editor

The chip editor appears during synthesis.

It allows the player to define:

* Name

* Description

* Package size

* Pin layout

* Pin names

* Pin direction

* Symbol appearance

* Test requirements

* Version number

The editor should produce a visual DIP-style preview.

Example:

┌────────────────┐  
│ JDB\_FULLADD    │  
│ A          SUM │  
│ B         COUT │  
│ CIN        VCC │  
│ GND            │  
└────────────────┘

---

## 8.4 Debugging Interface

Debugging tools should be highly visible and satisfying.

Important views:

* Current signal overlay

* Net highlight

* Logic probe popup

* Timing diagram

* Truth table

* Bus inspector

* Error list

* “Trace source of X” tool

* “Show all floating inputs” tool

* “Show bus conflicts” tool

---

## 9\. Visual Style

The visual style should be clean, tactile, and readable.

### Desired Feel

* Top-down electronics workbench

* Breadboards and DIP chips

* Colored jumper wires

* Subtle signal animation

* Clean labels

* Slight retro-computing influence

* Practical engineering aesthetic

### Avoid

* Excessive realism that harms readability

* Messy wire rendering with no abstraction

* Overly cartoonish components

* Tiny unreadable chip labels

* Visual noise at large scale

### Inspiration

* Breadboard prototyping

* 1970s/1980s TTL computing

* Lab notebooks

* Logic analyzers

* Retro computer schematics

* Zachtronics interface clarity

* Turing Complete progression

* Minecraft redstone emergent complexity

---

## 10\. Audio Style

Audio should reinforce the feeling of a living electronics bench.

Potential sounds:

* Soft relay clicks

* Toggle switch clicks

* Clock pulses

* Wire placement snaps

* Chip insertion sounds

* Test pass chime

* Test fail buzz

* Oscilloscope-style beeps

* Low ambient lab hum

Audio should be subtle and not irritating during long building sessions.

---

## 11\. Technical Design

## 11.1 Data Model

### ChipDefinition

Represents a type of chip.

Fields:

* name

* pins

* internal circuit reference

* compiled behavior

* delay

* package type

* visual style

* version

* metadata

### ChipInstance

Represents a placed chip on the board.

Fields:

* chip definition

* board position

* rotation

* pin-to-net mapping

* internal state

* label

* visual overrides

### Net

Represents a connected electrical/logical node.

Fields:

* connected pins

* drivers

* current value

* next value

* error state

* label

* color

### Circuit

Represents a workspace or chip internal design.

Fields:

* components

* wires

* nets

* labels

* test benches

* subcircuits

* simulation state

---

## 11.2 Signal Resolution

Each net resolves its value from all connected drivers.

Basic rules:

* No drivers → Z

* One driver outputs 0 → 0

* One driver outputs 1 → 1

* Multiple drivers same value → that value

* Multiple conflicting drivers → X

* Any invalid condition → X

Inputs connected to Z may become X unless pulled high/low or explicitly allowed.

---

## 11.3 Simulation Tick

Each simulation tick:

1. Read current net states

2. Evaluate components

3. Produce proposed outputs

4. Resolve all nets

5. Update stateful components on clock edges

6. Record signal history for debugging

7. Detect errors or oscillation

8. Update visual overlays

Clocked components should update only on valid clock transitions.

---

## 11.4 Synthesis Compilation

When a circuit is synthesized:

1. Validate pin definitions

2. Validate no unresolved errors

3. Run required tests

4. Determine whether circuit is combinational or sequential

5. Generate chip metadata

6. Preserve internal design

7. Generate compiled behavior

8. Add chip to parts drawer

For small combinational circuits, the game can store a complete truth table.

For large or sequential circuits, the game can store a hierarchical netlist and optimized simulation representation.

---

## 12\. MVP Scope

The MVP should prove the full build-test-synthesize-reuse loop.

### MVP Components

* Infinite grid workspace

* Basic wire tool

* Signal simulation

* Buttons

* LEDs

* Clock

* Logic probe

* NAND

* NOT

* AND

* OR

* XOR

* Custom chip synthesis

* Save/load

### MVP Challenges

1. Turn on an LED

2. Build NOT from NAND

3. Build AND from NAND

4. Build XOR

5. Build half adder

6. Synthesize half adder

7. Build full adder from two half adders

8. Synthesize full adder

9. Build 4-bit adder using four full adders

### MVP Success Criteria

The MVP is successful if a player can:

* Place chips

* Wire pins

* Simulate logic

* Inspect signal states

* Debug a circuit

* Package a working circuit into a chip

* Reuse that chip in a larger circuit

* Save and reload the result

The ideal first major demo is:

The player builds a half adder, synthesizes it, uses two half adders and an OR gate to build a full adder, synthesizes that, then builds a 4-bit adder from four full adders.

---

## 13\. Full Game Scope

The full game should support:

* Larger component library

* Sequential logic

* RAM/ROM

* Custom chip hierarchy

* Timing diagrams

* Test benches

* Campaign missions

* Sandbox mode

* CPU construction

* Assembler

* Memory-mapped I/O

* Terminal/display output

* User-created challenges

* Chip sharing

* Circuit sharing

* Optimization scoring

---

## 14\. Potential Scoring Systems

Campaign puzzles may score based on:

* Component count

* Board area

* Wire length

* Propagation delay

* Maximum clock speed

* Power estimate

* Number of custom chips

* 74-series authenticity

* Test coverage

Scoring should be optional or secondary. The primary appeal is construction and discovery, not pure optimization.

---

## 15\. Risks and Design Challenges

### 15.1 Complexity Creep

The game could become too complex too quickly.

Mitigation:

* Start with tiny goals

* Use guided challenges

* Provide strong visualization

* Delay advanced timing issues

* Use optional expert rules

---

### 15.2 Wire Mess

Large breadboard circuits can become unreadable.

Mitigation:

* Net labels

* Bus ribbons

* Wire bundling

* Hide/show wire layers

* Signal highlighting

* Region grouping

* Custom chip synthesis

---

### 15.3 Simulation Performance

Large circuits may simulate slowly.

Mitigation:

* Hierarchical simulation

* Compiled chip behavior

* Truth table caching

* Dirty net evaluation

* Event-driven simulation

* Optional flattening only for debugging

---

### 15.4 Player Frustration

Digital logic debugging can be intimidating.

Mitigation:

* Excellent error messages

* Visual signal states

* Automated tests

* “Why is this X?” tracing

* Step-by-step tutorials

* Example circuits

* Forgiving early mode

---

### 15.5 Educational Burden

The game must teach without feeling like homework.

Mitigation:

* Make lessons goal-driven

* Use satisfying physical interactions

* Let players discover patterns

* Keep explanations short and contextual

* Reward experimentation

---

## 16\. Development Roadmap

### Phase 1: Prototype

Goal: prove core simulation and wiring.

Features:

* Grid workspace

* Basic chips

* Wires

* Signal resolution

* LEDs/buttons

* Run/pause/step

* Save/load simple circuit

---

### Phase 2: Synthesis Prototype

Goal: prove recursive chip creation.

Features:

* Select circuit region

* Define pins

* Create custom chip

* Place custom chip

* Preserve internals

* Reuse in larger design

---

### Phase 3: Puzzle MVP

Goal: create first playable teaching sequence.

Features:

* Challenge system

* Test benches

* Truth table validation

* Half adder challenge

* Full adder challenge

* 4-bit adder challenge

---

### Phase 4: Sequential Logic

Goal: support memory and clocks.

Features:

* Latches

* Flip-flops

* Counters

* Registers

* Timing diagram viewer

* Clock stepping

---

### Phase 5: CPU Path

Goal: support full simple CPU construction.

Features:

* RAM/ROM

* Bus tools

* ALU challenges

* Register file

* Program counter

* Instruction decoder

* Terminal output

---

### Phase 6: Sandbox and Sharing

Goal: long-term creativity.

Features:

* Custom challenge editor

* Chip import/export

* Circuit sharing

* Public library

* Optimization scoring

* User-made CPUs

---

## 17\. Example Player Journey

A new player begins with a blank board, a button, an LED, and a NAND chip.

They first wire a button to an LED. Then they learn that NAND can create NOT. They package their first inverter chip.

Next, they build AND, OR, and XOR. They combine those into a half adder and watch the Sum and Carry LEDs respond correctly.

They synthesize the half adder into a custom chip.

Then they place two copies of their half adder, add an OR gate, and create a full adder. That becomes another chip.

Four full adders become a 4-bit adder. The 4-bit adder becomes part of an ALU. The ALU becomes part of a CPU.

Eventually, the player writes a tiny program for their own CPU and sees output on a terminal:

HELLO

At that moment, the player understands that the computer is not magic. It is a tower of understandable pieces they built themselves.

---

## 18\. Unique Selling Points

* Build a CPU from 74-series-style logic

* Infinite breadboard workspace

* Recursively synthesize custom chips from player-built circuits

* Preserve and inspect chip internals

* Strong debugging tools

* Campaign that teaches real computer architecture concepts

* Sandbox for custom CPUs and architectures

* Player-created component libraries

* Physical breadboard aesthetic with accessible digital simulation

---

## 19\. One-Sentence Pitch

**The Infinite Breadboard** is a logic-building game where you start with 74-series chips, recursively package your own circuits into custom ICs, and eventually build a complete computer from components you designed yourself.

---

## 20\. Design Summary

The heart of the game is recursive abstraction.

The player does not merely unlock better parts. They create better parts.

A working circuit becomes a chip. That chip becomes a subsystem. That subsystem becomes a computer.

The game should make the player feel like they are discovering the hidden ladder between NAND gates and CPUs, one satisfying synthesis step at a time.