import { computed } from "@ember/object";
import { classNameBindings } from "@ember-decorators/component";
import TextField from "discourse/components/text-field";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { allowOnlyNumericInput } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

@classNameBindings("invalid")
export default class NumberField extends TextField {
  init() {
    super.init(...arguments);
    deprecated(
      `NumberField component is deprecated. Use native <input> elements instead.\ne.g. <input {{on "input" (with-event-value (fn (mut this.value)))}} type="number" value={{this.value}} />`,
      {
        id: "discourse.number-field",
        since: "3.2.0.beta5",
        dropFrom: "3.3.0",
      }
    );
  }

  keyDown(event) {
    allowOnlyNumericInput(event, this._minNumber && this._minNumber < 0);
  }

  get _minNumber() {
    if (!this.get("min")) {
      return;
    }
    return parseInt(this.get("min"), 10);
  }

  get _maxNumber() {
    if (!this.get("max")) {
      return;
    }
    return parseInt(this.get("max"), 10);
  }

  @computed("number")
  get value() {
    if (this.number === null) {
      return "";
    }
    return parseInt(this.number, 10);
  }

  set value(value) {
    const num = parseInt(value, 10);
    if (isNaN(num)) {
      this.set("invalid", true);
      this.set("number", null);
    } else {
      this.set("invalid", false);
      this.set("number", num);
    }
  }

  @discourseComputed("placeholderKey")
  placeholder(key) {
    return key ? i18n(key) : "";
  }
}
