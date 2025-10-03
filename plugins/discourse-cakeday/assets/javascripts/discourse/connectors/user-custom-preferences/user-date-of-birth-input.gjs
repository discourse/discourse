import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { classNames, tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

@tagName("div")
@classNames("user-custom-preferences-outlet", "user-date-of-birth-input")
export default class UserDateOfBirthInput extends Component {
  init() {
    super.init(...arguments);
    const { model } = this;
    const { birthdate } = model;
    const months = moment.months().map((month, index) => {
      return {
        name: month,
        value: index + 1,
      };
    });
    const days = [...Array(31).keys()].map((d) => (d + 1).toString());
    const month = birthdate
      ? moment(birthdate, "YYYY-MM-DD").month() + 1
      : null;
    const day = birthdate
      ? moment(birthdate, "YYYY-MM-DD").date().toString()
      : null;
    this.setProperties({
      months,
      days,
      month,
      day,
    });
    const updateBirthdate = () => {
      let date = "";
      if (this.month && this.day) {
        date = `1904-${this.month}-${this.day}`;
      }

      // The property that is being serialized when sending the update
      // request to the server is called `date_of_birth`
      model.set("date_of_birth", date);
    };
    this.addObserver("month", updateBirthdate);
    this.addObserver("day", updateBirthdate);
  }

  <template>
    {{#if this.siteSettings.cakeday_birthday_enabled}}
      <div class="control-group">
        <label class="control-label">{{i18n "user.date_of_birth.label"}}</label>
        <div class="controls">
          <ComboBox
            @content={{this.months}}
            @value={{this.month}}
            @valueAttribute="value"
            @valueProperty="value"
            @none="cakeday.none"
            @options={{hash clearable=true autoInsertNoneItem=false}}
            @onChange={{fn (mut this.month)}}
          />

          <ComboBox
            @content={{this.days}}
            @value={{this.day}}
            @valueProperty={{null}}
            @nameProperty={{null}}
            @none="cakeday.none"
            @options={{hash clearable=true autoInsertNoneItem=false}}
            @onChange={{fn (mut this.day)}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
