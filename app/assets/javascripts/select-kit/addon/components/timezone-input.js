import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("timezone-input")
@selectKitOptions({
  filterable: true,
  allowAny: false,
})
@pluginApiIdentifiers("timezone-input")
export default class TimezoneInput extends ComboBoxComponent {
  get nameProperty() {
    return this.isLocalized ? "name" : null;
  }

  get valueProperty() {
    return this.isLocalized ? "value" : null;
  }

  get content() {
    return this.isLocalized ? moment.tz.localizedNames() : moment.tz.names();
  }

  get isLocalized() {
    return (
      moment.locale() !== "en" && typeof moment.tz.localizedNames === "function"
    );
  }

  _onChangeWrapper(timezone) {
    // We support IST for India, but IST is not a valid timezone
    // it's ambiguous with other timezones like Dublin or Jerusalem
    if (timezone === "IST") {
      this.addError(i18n("timezone_input.ambiguous_ist"));
      return null;
    }

    return super._onChangeWrapper(timezone);
  }
}
