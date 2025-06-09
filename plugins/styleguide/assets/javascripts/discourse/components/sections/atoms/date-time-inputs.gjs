import DateInput from "discourse/components/date-input";
import DatePicker from "discourse/components/date-picker";
import DateTimeInput from "discourse/components/date-time-input";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import FutureDateInput from "discourse/components/future-date-input";
import TimeInput from "discourse/components/time-input";
import CalendarDateTimeInput from "discourse/plugins/styleguide/discourse/components/styleguide/calendar-date-time-input";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const DateTimeInputs = <template>
  <StyleguideExample @title="<TimeInput>">
    <TimeInput />
  </StyleguideExample>

  <StyleguideExample @title="<DateInput>">
    <DateInput />
  </StyleguideExample>

  <StyleguideExample @title="<DateTimeInput>">
    <DateTimeInput @clearable={{true}} />
  </StyleguideExample>

  <StyleguideExample @title="<DateTimeInputRange>">
    <DateTimeInputRange />
  </StyleguideExample>

  <StyleguideExample @title="<DateTimeInputRange>">
    <DateTimeInputRange @showFromTime={{false}} @showToTime={{false}} />
  </StyleguideExample>

  <StyleguideExample @title="<FutureDateInput>">
    <FutureDateInput @displayLabelIcon="far-clock" @clearable={{true}} />
  </StyleguideExample>

  <StyleguideExample @title="<DatePicker>">
    <DatePicker @defaultDate="YYYY-MM-DD" />
  </StyleguideExample>

  <CalendarDateTimeInput />
</template>;

export default DateTimeInputs;
