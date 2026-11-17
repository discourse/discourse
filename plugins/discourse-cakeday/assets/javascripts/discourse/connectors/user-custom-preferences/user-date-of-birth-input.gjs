import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class UserDateOfBirthInput extends Component {
  @service siteSettings;

  /** @type {number | null} */
  @tracked month = null;

  /** @type {string | null} */
  @tracked day = null;

  months = moment.months().map((name, index) => ({ name, value: index + 1 }));
  days = [...Array(31).keys()].map((d) => (d + 1).toString());

  constructor() {
    super(...arguments);

    const { birthdate } = this.args.model;
    if (birthdate) {
      const date = moment(birthdate, "YYYY-MM-DD");
      this.month = date.month() + 1;
      this.day = date.date().toString();
    }
  }

  @action
  changeMonth(month) {
    this.month = month;
    this.#updateBirthdate();
  }

  @action
  changeDay(day) {
    this.day = day;
    this.#updateBirthdate();
  }

  #updateBirthdate() {
    // The property that is being serialized when sending the update
    // request to the server is called `date_of_birth`
    this.args.model.set(
      "date_of_birth",
      this.month && this.day ? `1904-${this.month}-${this.day}` : ""
    );
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
              @onChange={{this.changeMonth}}
              @options={{hash clearable=true autoInsertNoneItem=false}}
              @value={{this.month}}
              @valueAttribute="value"
              @valueProperty="value"
            />

            <ComboBox
              @content={{this.days}}
              @nameProperty={{null}}
              @none="cakeday.none"
              @onChange={{this.changeDay}}
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
