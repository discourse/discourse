import DCalendarDateTimeInput from "discourse/ui-kit/d-calendar-date-time-input";

export default <template>
  <DCalendarDateTimeInput
    @datePickerId="styleguide"
    @date={{@date}}
    @time={{@time}}
    @minDate={{@minDate}}
    @dateFormat="YYYY-MM-DD"
    @timeFormat="HH:mm:ss"
    @onChangeDate={{@onChangeDate}}
    @onChangeTime={{@onChangeTime}}
  />
</template>
