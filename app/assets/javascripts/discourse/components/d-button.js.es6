import { notEmpty, empty } from "@ember/object/computed";
import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";
import DiscourseURL from "discourse/lib/url";

export default Component.extend({
  // subclasses need this
  layoutName: "components/d-button",

  form: null,

  type: "button",

  tagName: "button",
  classNameBindings: [":btn", "noText", "btnType"],
  attributeBindings: [
    "form",
    "disabled",
    "translatedTitle:title",
    "translatedLabel:aria-label",
    "tabindex",
    "type"
  ],

  btnIcon: notEmpty("icon"),

  @computed("icon", "translatedLabel")
  btnType(icon, translatedLabel) {
    if (icon) {
      return translatedLabel ? "btn-icon-text" : "btn-icon";
    } else if (translatedLabel) {
      return "btn-text";
    }
  },

  noText: empty("translatedLabel"),

  @computed("title")
  translatedTitle: {
    get() {
      if (this._translatedTitle) return this._translatedTitle;
      if (this.title) return I18n.t(this.title);
    },
    set(value) {
      return (this._translatedTitle = value);
    }
  },

  @computed("label")
  translatedLabel: {
    get() {
      if (this._translatedLabel) return this._translatedLabel;
      if (this.label) return I18n.t(this.label);
    },
    set(value) {
      return (this._translatedLabel = value);
    }
  },

  click() {
    let { action } = this;

    if (action) {
      if (typeof action === "string") {
        this.sendAction("action", this.actionParam);
      } else if (typeof action === "object" && action.value) {
        action.value(this.actionParam);
      } else if (typeof this.action === "function") {
        action(this.actionParam);
      }
    }

    if (this.href && this.href.length) {
      DiscourseURL.routeTo(this.href);
    }

    return false;
  }
});
