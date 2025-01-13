import { TextField } from "@ember/legacy-built-in-components";
import { computed } from "@ember/object";
import { cancel, next } from "@ember/runloop";
import { attributeBindings } from "@ember-decorators/component";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";

const DEBOUNCE_MS = 500;

@attributeBindings(
  "autocorrect",
  "autocapitalize",
  "autofocus",
  "maxLength",
  "dir",
  "aria-label",
  "aria-controls"
)
export default class DiscourseTextField extends TextField {
  _prevValue = null;
  _timer = null;

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    this._prevValue = this.value;
  }

  didUpdateAttrs() {
    super.didUpdateAttrs(...arguments);

    if (this._prevValue !== this.value) {
      if (this.onChangeImmediate) {
        next(() => this.onChangeImmediate(this.value));
      }
      if (this.onChange) {
        cancel(this._timer);
        this._timer = discourseDebounce(
          this,
          this._debouncedChange,
          DEBOUNCE_MS
        );
      }
    }
  }

  _debouncedChange() {
    next(() => this.onChange(this.value));
  }

  get dir() {
    if (this.siteSettings.support_mixed_text_direction) {
      return "auto";
    }
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    cancel(this._timer);
  }

  @computed("placeholderKey", "_placeholder")
  get placeholder() {
    if (this._placeholder) {
      return this._placeholder;
    }
    return this.placeholderKey ? i18n(this.placeholderKey) : "";
  }

  set placeholder(value) {
    this.set("_placeholder", value);
  }
}
