import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";

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
}

<StyleguideExample @title="<CalendarDateTimeInput>">
  <Styleguide::Component>
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
  </Styleguide::Component>

  <Styleguide::Controls>
    <Styleguide::Controls::Row @name="Min date">
      <DatePicker @defaultDate="YYYY-MM-DD" @value={{this.minDate}} />
    </Styleguide::Controls::Row>

    <Styleguide::Controls::Row @name="Date">
      <DatePicker @defaultDate="YYYY-MM-DD" @value={{this.date}} />
    </Styleguide::Controls::Row>

    <Styleguide::Controls::Row @name="Time">
      <Input
        maxlength={{5}}
        placeholder="hh:mm"
        @type="time"
        @value={{this.time}}
        class="time-picker"
      />
    </Styleguide::Controls::Row>
  </Styleguide::Controls>
</StyleguideExample>