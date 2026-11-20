# Roadmap

## Overview

Hamilton is being developed as a tool for modeling and simulating systems. We are
figuring out the details as we go; this roadmap captures the high-level direction,
not every task or a fixed delivery schedule. The current plugin provides a
configurable greeting and public documentation. The modeling and simulation
capabilities below are planned.

Update this roadmap when work diverges significantly from the direction described
here, or when capturing future intentions would help guide development.

## Goals

- Build a visual editor where users can drag and drop elements onto a canvas,
  connect them, and define their relationships.
- Simulate how a system changes over time and plot its variables across time.
- Provide a draggable time cursor to explore the system’s state at any point in
  the simulation.
- Use the systems and modeling design language in *Thinking in Systems* by
  Donella H. Meadows as inspiration.

## Milestones

1. **Model simple systems.** Start with toy systems such as a bathtub with a tap
   and drain. Define how the filling and draining rates determine the water level.
2. **Simulate and inspect change.** Run those systems over time, plot their
   variables, and explore their state with the draggable time cursor.
3. **Explore feedback.** Model a heating system with a thermostat to explore how
   feedback affects behavior over time.
