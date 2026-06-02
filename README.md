# Breadboard 74

A Godot 4 prototype for a digital logic construction game where players build circuits from 74-series-style components and eventually package those circuits into reusable chips.

## Current Slice

- Godot main scene with a pan/zoom workbench.
- Selectable level presets: NAND starter, half adder, full adder, and sandbox.
- MS Paint-style toolbox for pointer, wire, and repeated chip/part placement.
- Real 74LS DIP pinouts for NAND, NOT, AND, OR, and XOR chips; IC outputs require VCC on pin 14 and GND on pin 7.
- Breadboard terminal strips and rails are represented as passive bus members inside nets; manual jumper wires snap to pins, terminal strips, and power rails.
- Small simulator core for nets, signal resolution, chip definitions, and basic gates.
- Headless simulator tests for signal resolution, gate truth tables, and bus conflicts.

## Commands

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 -s res://tests/sim_tests.gd
```

## Likely Next Step

Give two-pin parts independent breadboard leg placement so LEDs and resistors can span real rows cleanly in sandbox builds.
