import DRelativeTimePicker from "discourse/ui-kit/d-relative-time-picker";

export default <template>
  <DRelativeTimePicker
    @durationHours={{@field.value}}
    @durationOutputUnit="hours"
    @onChange={{@field.set}}
  />
</template>
