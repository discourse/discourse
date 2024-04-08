import { TextField } from "@ember/legacy-built-in-components";
import { cancel, next } from "@ember/runloop";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

const DEBOUNCE_MS = 500;

export default TextField.extend({
  attributeBindings: [
    "autocorrect",
    "autocapitalize",
    "autofocus",
    "maxLength",
    "dir",
    "aria-label",
    "aria-controls",
  ],

  init() {
    this._super(...arguments);

    this._prevValue = null;
    this._timer = null;
  },

  didReceiveAttrs() {
    this._super(...arguments);

    this._prevValue = this.value;
  },

  didUpdateAttrs() {
    this._super(...arguments);

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
  },

  _debouncedChange() {
    next(() => this.onChange(this.value));
  },

  get dir() {
    if (this.siteSettings.support_mixed_text_direction) {
      return "auto";
    }
  },

  willDestroyElement() {
    this._super(...arguments);
    cancel(this._timer);
  },

  @discourseComputed("placeholderKey")
  placeholder: {
    get() {
      if (this._placeholder) {
        return this._placeholder;
      }
      return this.placeholderKey ? I18n.t(this.placeholderKey) : "";
    },
    set(value) {
      return (this._placeholder = value);
    },
  },
});
