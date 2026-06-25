import DRelativeTimePicker from "discourse/ui-kit/d-relative-time-picker";

<template>
  <DRelativeTimePicker
    @durationHours={{@field.value}}
    @durationOutputUnit="hours"
    @onChange={{@field.set}}
  />
</template>
