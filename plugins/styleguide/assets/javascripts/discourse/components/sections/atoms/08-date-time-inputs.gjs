import Component from "@glimmer/component";
import DateInput from "discourse/ui-kit/d-date-input";
import DatePicker from "discourse/ui-kit/d-date-picker/d-date-picker";
import DateTimeInput from "discourse/ui-kit/d-date-time-input";
import DateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";
import FutureDateInput from "discourse/ui-kit/d-future-date-input";
import TimeInput from "discourse/ui-kit/d-time-input";
import CalendarDateTimeInput from "discourse/plugins/styleguide/discourse/components/styleguide/calendar-date-time-input";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class DateTimeInputs extends Component {
  get timeInputCode() {
    return `
import TimeInput from "discourse/ui-kit/d-time-input";

<template>
  <TimeInput />
</template>
    `;
  }

  get dateInputCode() {
    return `
import DateInput from "discourse/ui-kit/d-date-input";

<template>
  <DateInput />
</template>
    `;
  }

  get dateTimeInputCode() {
    return `
import DateTimeInput from "discourse/ui-kit/d-date-time-input";

<template>
  <DateTimeInput @clearable={{true}} />
</template>
    `;
  }

  get dateTimeInputRangeCode() {
    return `
import DateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";

<template>
  <DateTimeInputRange />
</template>
    `;
  }

  get dateTimeInputRangeNoTimeCode() {
    return `
import DateTimeInputRange from "discourse/ui-kit/d-date-time-input-range";

<template>
  <DateTimeInputRange @showFromTime={{false}} @showToTime={{false}} />
</template>
    `;
  }

  get futureDateInputCode() {
    return `
import FutureDateInput from "discourse/ui-kit/d-future-date-input";

<template>
  <FutureDateInput @displayLabelIcon="far-clock" @clearable={{true}} />
</template>
    `;
  }

  get datePickerCode() {
    return `
import DatePicker from "discourse/ui-kit/d-date-picker/d-date-picker";

<template>
  <DatePicker @defaultDate="YYYY-MM-DD" />
</template>
    `;
  }

  <template>
    <StyleguideExample @title="TimeInput" @code={{this.timeInputCode}}>
      <TimeInput />
    </StyleguideExample>

    <StyleguideExample @title="DateInput" @code={{this.dateInputCode}}>
      <DateInput />
    </StyleguideExample>

    <StyleguideExample @title="DateTimeInput" @code={{this.dateTimeInputCode}}>
      <DateTimeInput @clearable={{true}} />
    </StyleguideExample>

    <StyleguideExample
      @title="DateTimeInputRange"
      @code={{this.dateTimeInputRangeCode}}
    >
      <DateTimeInputRange />
    </StyleguideExample>

    <StyleguideExample
      @title="DateTimeInputRange without time"
      @code={{this.dateTimeInputRangeNoTimeCode}}
    >
      <DateTimeInputRange @showFromTime={{false}} @showToTime={{false}} />
    </StyleguideExample>

    <StyleguideExample
      @title="FutureDateInput"
      @code={{this.futureDateInputCode}}
    >
      <FutureDateInput @displayLabelIcon="far-clock" @clearable={{true}} />
    </StyleguideExample>

    <StyleguideExample @title="DatePicker" @code={{this.datePickerCode}}>
      <DatePicker @defaultDate="YYYY-MM-DD" />
    </StyleguideExample>

    <CalendarDateTimeInput />
  </template>
}
