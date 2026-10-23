import CalendarDateTimeInput from "discourse/plugins/styleguide/discourse/components/styleguide/calendar-date-time-input";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import DateInputExample from "../../examples/atoms/date-time-inputs/date-input.gjs";
import dateInputSource from "../../examples/atoms/date-time-inputs/date-input?source=file";
import DatePickerExample from "../../examples/atoms/date-time-inputs/date-picker.gjs";
import datePickerSource from "../../examples/atoms/date-time-inputs/date-picker?source=file";
import DateTimeInputExample from "../../examples/atoms/date-time-inputs/date-time-input.gjs";
import dateTimeInputSource from "../../examples/atoms/date-time-inputs/date-time-input?source=file";
import DateTimeInputRangeExample from "../../examples/atoms/date-time-inputs/date-time-input-range.gjs";
import dateTimeInputRangeSource from "../../examples/atoms/date-time-inputs/date-time-input-range?source=file";
import DateTimeInputRangeWithoutTimeExample from "../../examples/atoms/date-time-inputs/date-time-input-range-without-time.gjs";
import dateTimeInputRangeWithoutTimeSource from "../../examples/atoms/date-time-inputs/date-time-input-range-without-time?source=file";
import FutureDateInputExample from "../../examples/atoms/date-time-inputs/future-date-input.gjs";
import futureDateInputSource from "../../examples/atoms/date-time-inputs/future-date-input?source=file";
import TimeInputExample from "../../examples/atoms/date-time-inputs/time-input.gjs";
import timeInputSource from "../../examples/atoms/date-time-inputs/time-input?source=file";

export default <template>
  <StyleguideExample @code={{timeInputSource}} @title="TimeInput">
    <TimeInputExample />
  </StyleguideExample>

  <StyleguideExample @code={{dateInputSource}} @title="DateInput">
    <DateInputExample />
  </StyleguideExample>

  <StyleguideExample @code={{dateTimeInputSource}} @title="DateTimeInput">
    <DateTimeInputExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{dateTimeInputRangeSource}}
    @title="DateTimeInputRange"
  >
    <DateTimeInputRangeExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{dateTimeInputRangeWithoutTimeSource}}
    @title="DateTimeInputRange without time"
  >
    <DateTimeInputRangeWithoutTimeExample />
  </StyleguideExample>

  <StyleguideExample @code={{futureDateInputSource}} @title="FutureDateInput">
    <FutureDateInputExample />
  </StyleguideExample>

  <StyleguideExample @code={{datePickerSource}} @title="DatePicker">
    <DatePickerExample />
  </StyleguideExample>

  <CalendarDateTimeInput />
</template>
