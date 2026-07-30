import CalendarDateTimeInput from "discourse/plugins/styleguide/discourse/components/styleguide/calendar-date-time-input";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import DateInputExample from "../../examples/atoms/date-time-inputs/date-input";
import dateInputSource from "../../examples/atoms/date-time-inputs/date-input?source=file";
import DatePickerExample from "../../examples/atoms/date-time-inputs/date-picker";
import datePickerSource from "../../examples/atoms/date-time-inputs/date-picker?source=file";
import DateTimeInputExample from "../../examples/atoms/date-time-inputs/date-time-input";
import dateTimeInputSource from "../../examples/atoms/date-time-inputs/date-time-input?source=file";
import DateTimeInputRangeExample from "../../examples/atoms/date-time-inputs/date-time-input-range";
import dateTimeInputRangeSource from "../../examples/atoms/date-time-inputs/date-time-input-range?source=file";
import DateTimeInputRangeWithoutTimeExample from "../../examples/atoms/date-time-inputs/date-time-input-range-without-time";
import dateTimeInputRangeWithoutTimeSource from "../../examples/atoms/date-time-inputs/date-time-input-range-without-time?source=file";
import FutureDateInputExample from "../../examples/atoms/date-time-inputs/future-date-input";
import futureDateInputSource from "../../examples/atoms/date-time-inputs/future-date-input?source=file";
import TimeInputExample from "../../examples/atoms/date-time-inputs/time-input";
import timeInputSource from "../../examples/atoms/date-time-inputs/time-input?source=file";

export default <template>
  <StyleguideExample @title="TimeInput" @code={{timeInputSource}}>
    <TimeInputExample />
  </StyleguideExample>

  <StyleguideExample @title="DateInput" @code={{dateInputSource}}>
    <DateInputExample />
  </StyleguideExample>

  <StyleguideExample @title="DateTimeInput" @code={{dateTimeInputSource}}>
    <DateTimeInputExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DateTimeInputRange"
    @code={{dateTimeInputRangeSource}}
  >
    <DateTimeInputRangeExample />
  </StyleguideExample>

  <StyleguideExample
    @title="DateTimeInputRange without time"
    @code={{dateTimeInputRangeWithoutTimeSource}}
  >
    <DateTimeInputRangeWithoutTimeExample />
  </StyleguideExample>

  <StyleguideExample @title="FutureDateInput" @code={{futureDateInputSource}}>
    <FutureDateInputExample />
  </StyleguideExample>

  <StyleguideExample @title="DatePicker" @code={{datePickerSource}}>
    <DatePickerExample />
  </StyleguideExample>

  <CalendarDateTimeInput />
</template>
