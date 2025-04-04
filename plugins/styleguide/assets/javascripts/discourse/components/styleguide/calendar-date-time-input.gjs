import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CalendarDateTimeInput from "discourse/components/calendar-date-time-input";
import DatePicker from "discourse/components/date-picker";
import StyleguideComponent from "discourse/plugins/styleguide/discourse/components/styleguide/component";
import Controls from "discourse/plugins/styleguide/discourse/components/styleguide/controls";
import Row from "discourse/plugins/styleguide/discourse/components/styleguide/controls/row";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class StyleguideCalendarDateTimeInput extends Component {
  @service currentUser;

  @tracked dateFormat = "YYYY-MM-DD";
  @tracked timeFormat = "HH:mm:ss";
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
    <StyleguideExample @title="<CalendarDateTimeInput>">
      <StyleguideComponent>
        <CalendarDateTimeInput
          @datePickerId="styleguide"
          @date={{this.date}}
          @time={{this.time}}
          @minDate={{this.minDate}}
          @timeFormat={{this.timeFormat}}
          @dateFormat={{this.dateFormat}}
          @onChangeDate={{this.changeDate}}
          @onChangeTime={{this.changeTime}}
        />
      </StyleguideComponent>

      <Controls>
        <Row @name="Min date">
          <DatePicker @defaultDate="YYYY-MM-DD" @value={{this.minDate}} />
        </Row>

        <Row @name="Date">
          <DatePicker @defaultDate="YYYY-MM-DD" @value={{this.date}} />
        </Row>

        <Row @name="Time">
          <Input
            maxlength={{5}}
            placeholder="hh:mm"
            @type="time"
            @value={{this.time}}
            class="time-picker"
          />
        </Row>
      </Controls>
    </StyleguideExample>
  </template>
}
