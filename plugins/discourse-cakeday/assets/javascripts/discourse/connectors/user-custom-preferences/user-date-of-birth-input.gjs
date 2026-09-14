/* eslint-disable ember/no-classic-components, ember/no-observers */
import Component from "@ember/component";
import { fn, hash } from "@ember/helper";
import { tagName } from "@ember-decorators/component";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

@tagName("")
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
    <div
      class="user-custom-preferences-outlet user-date-of-birth-input"
      ...attributes
    >
      {{#if this.siteSettings.cakeday_birthday_enabled}}
        <div class="control-group">
          <label class="control-label">{{i18n
              "user.date_of_birth.label"
            }}</label>
          <div class="controls">
            <ComboBox
              @content={{this.months}}
              @none="cakeday.none"
              @onChange={{fn (mut this.month)}}
              @options={{hash clearable=true autoInsertNoneItem=false}}
              @value={{this.month}}
              @valueAttribute="value"
              @valueProperty="value"
            />

            <ComboBox
              @content={{this.days}}
              @nameProperty={{null}}
              @none="cakeday.none"
              @onChange={{fn (mut this.day)}}
              @options={{hash clearable=true autoInsertNoneItem=false}}
              @value={{this.day}}
              @valueProperty={{null}}
            />
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
