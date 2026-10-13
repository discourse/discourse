import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import DDatePicker from "discourse/ui-kit/d-date-picker";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CalendarDateTimeInputExample from "../examples/atoms/date-time-inputs/calendar-date-time-input";
import calendarDateTimeInputSource from "../examples/atoms/date-time-inputs/calendar-date-time-input?source=file";

export default class StyleguideCalendarDateTimeInput extends Component {
  @tracked date = null;
  @tracked time = null;
  @tracked minDate = null;

  @action
  changeDate(date) {
    this.date = date;
  }

  @action
  changeTime(time) {
    this.time = time;
  }

  <template>
    <StyleguideExample
      @code={{calendarDateTimeInputSource}}
      @title="CalendarDateTimeInput"
    >
      <StyleguideComponent>
        <CalendarDateTimeInputExample
          @date={{this.date}}
          @minDate={{this.minDate}}
          @onChangeDate={{this.changeDate}}
          @onChangeTime={{this.changeTime}}
          @time={{this.time}}
        />
      </StyleguideComponent>

      <Controls>
        <Row @name="Min date">
          <DDatePicker @defaultDate="YYYY-MM-DD" @value={{this.minDate}} />
        </Row>

        <Row @name="Date">
          <DDatePicker @defaultDate="YYYY-MM-DD" @value={{this.date}} />
        </Row>

        <Row @name="Time">
          <Input
            class="time-picker"
            maxlength={{5}}
            placeholder="hh:mm"
            @type="time"
            @value={{this.time}}
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
