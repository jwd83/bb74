# Breadboard 74

A Godot 4 prototype for a digital logic construction game where players build circuits from 74-series-style components and eventually package those circuits into reusable chips.

## Current Slice

- Godot main scene with a pan/zoom workbench.
- Selectable level presets: NAND starter, half adder, full adder, and sandbox.
- MS Paint-style toolbox for pointer, wire, and repeated chip/part placement.
- Real 74LS DIP pinouts for NAND, NOT, AND, OR, and XOR chips; IC outputs require VCC on pin 14 and GND on pin 7.
- Inputs are real pushbutton switches, not magic sources: each straddles the centre groove with its top leg jumpered to the + rail and its signal leg held LOW by a pull-down resistor to the - rail, so pressing it ties the node to +5V.
- Breadboard terminal strips and rails are buses; every connection is an explicit jumper wire between two distinct holes, and no two pins or wire ends ever share a hole. Signals fan out by taking extra holes on a strip rather than stacking on one.
- Simulator core resolves nets with drive strength: strong drivers (supplies, gate outputs, closed switches) override weak pull resistors.
- Headless simulator tests for signal resolution, gate truth tables, and bus conflicts, plus level tests that check hole uniqueness, pull-down switch inputs, and the built-in level truth tables.

## Commands

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 -s res://tests/sim_tests.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 -s res://tests/level_tests.gd
```

## Likely Next Step

Give two-pin parts independent breadboard leg placement so LEDs and resistors can span real rows cleanly in sandbox builds.
