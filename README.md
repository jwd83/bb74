# Breadboard 74

A Godot 4 prototype for a digital logic construction game where players build circuits from 74-series-style components and eventually package those circuits into reusable chips.

## Current Slice

- Godot main scene with a pan/zoom workbench.
- Hardcoded demo circuit: two toggles feed a NAND gate and LED.
- MS Paint-style toolbox for pointer, wire, and repeated chip/part placement.
- Small simulator core for nets, signal resolution, chip definitions, and basic gates.
- Headless simulator tests for signal resolution, gate truth tables, and bus conflicts.

## Commands

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 --quit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jared/projects/bb74 -s res://tests/sim_tests.gd
```

## Likely Next Step

Add direct manipulation for placed parts: select, drag/snap, delete, and undo basic edits.
