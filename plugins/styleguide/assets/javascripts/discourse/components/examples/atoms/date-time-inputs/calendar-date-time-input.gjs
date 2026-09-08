import DCalendarDateTimeInput from "discourse/ui-kit/d-calendar-date-time-input";

export default <template>
  <DCalendarDateTimeInput
    @date={{@date}}
    @dateFormat="YYYY-MM-DD"
    @datePickerId="styleguide"
    @minDate={{@minDate}}
    @onChangeDate={{@onChangeDate}}
    @onChangeTime={{@onChangeTime}}
    @time={{@time}}
    @timeFormat="HH:mm:ss"
  />
</template>
