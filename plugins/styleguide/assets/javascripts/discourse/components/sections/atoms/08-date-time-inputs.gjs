import Component from "@glimmer/component";
import DDateInput from "discourse/ui-kit/d-date-input";
import DDatePicker from "discourse/ui-kit/d-date-picker";
import DDateTimeInput from "discourse/ui-kit/d-date-time-input";
import DDateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import DTimeInput from "discourse/ui-kit/d-time-input";
import CalendarDateTimeInput from "discourse/plugins/styleguide/discourse/components/styleguide/calendar-date-time-input";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class DateTimeInputs extends Component {
  get timeInputCode() {
    return `
import TimeInput from "discourse/components/time-input";

<template>
  <TimeInput />
</template>
    `;
  }

  get dateInputCode() {
    return `
import DateInput from "discourse/components/date-input";

<template>
  <DateInput />
</template>
    `;
  }

  get dateTimeInputCode() {
    return `
import DateTimeInput from "discourse/components/date-time-input";

<template>
  <DateTimeInput @clearable={{true}} />
</template>
    `;
  }

  get dateTimeInputRangeCode() {
    return `
import DateTimeInputRange from "discourse/components/date-time-input-range";

<template>
  <DateTimeInputRange />
</template>
    `;
  }

  get dateTimeInputRangeNoTimeCode() {
    return `
import DateTimeInputRange from "discourse/components/date-time-input-range";

<template>
  <DateTimeInputRange @showFromTime={{false}} @showToTime={{false}} />
</template>
    `;
  }

  get futureDateInputCode() {
    return `
import FutureDateInput from "discourse/components/future-date-input";

<template>
  <FutureDateInput @displayLabelIcon="far-clock" @clearable={{true}} />
</template>
    `;
  }

  get datePickerCode() {
    return `
import DatePicker from "discourse/components/date-picker";

<template>
  <DatePicker @defaultDate="YYYY-MM-DD" />
</template>
    `;
  }

  <template>
    <StyleguideExample @title="TimeInput" @code={{this.timeInputCode}}>
      <DTimeInput />
    </StyleguideExample>

    <StyleguideExample @title="DateInput" @code={{this.dateInputCode}}>
      <DDateInput />
    </StyleguideExample>

    <StyleguideExample @title="DateTimeInput" @code={{this.dateTimeInputCode}}>
      <DDateTimeInput @clearable={{true}} />
    </StyleguideExample>

    <StyleguideExample
      @title="DateTimeInputRange"
      @code={{this.dateTimeInputRangeCode}}
    >
      <DDateTimeInputRange />
    </StyleguideExample>

    <StyleguideExample
      @title="DateTimeInputRange without time"
      @code={{this.dateTimeInputRangeNoTimeCode}}
    >
      <DDateTimeInputRange @showFromTime={{false}} @showToTime={{false}} />
    </StyleguideExample>

    <StyleguideExample
      @title="FutureDateInput"
      @code={{this.futureDateInputCode}}
    >
      <DFutureDateInput @displayLabelIcon="far-clock" @clearable={{true}} />
    </StyleguideExample>

    <StyleguideExample @title="DatePicker" @code={{this.datePickerCode}}>
      <DDatePicker @defaultDate="YYYY-MM-DD" />
    </StyleguideExample>

    <CalendarDateTimeInput />
  </template>
}
