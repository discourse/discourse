/* eslint-disable ember/no-classic-components */
/* eslint-disable ember/no-classic-classes */
import { MUTABLE_CELL } from "@ember/-internals/views";
import Component from "@ember/component";
import { computed, get, set } from "@ember/object";

const inputTypes = Object.create(null);
function canSetTypeOfInput(type) {
  if (type in inputTypes) {
    return inputTypes[type];
  }

  let inputTypeTestElement = document.createElement("input");

  try {
    inputTypeTestElement.type = type;
  } catch {
    // ignored
  }

  return (inputTypes[type] = inputTypeTestElement.type === type);
}

const KEY_EVENTS = {
  Enter: "insertNewline",
  Escape: "cancel",
};

function sendAction(eventName, view, event) {
  let action = get(view, `attrs.${eventName}`);
  if (
    action !== null &&
    typeof action === "object" &&
    action[MUTABLE_CELL] === true
  ) {
    action = action.value;
  }

  if (action === undefined) {
    action = get(view, eventName);
  }

  let value = view.value;

  if (typeof action === "function") {
    action(value, event);
  }

  if (action && !view.bubbles) {
    event.stopPropagation();
  }
}

const TextField = Component.extend({
  classNames: ["ember-text-field"],
  tagName: "input",

  attributeBindings: [
    "accept",
    "autocomplete",
    "autosave",
    "dir",
    "formaction",
    "formenctype",
    "formmethod",
    "formnovalidate",
    "formtarget",
    "height",
    "inputmode",
    "lang",
    "list",
    "type", // needs to be before min and max. See #15675
    "max",
    "min",
    "multiple",
    "name",
    "pattern",
    "size",
    "step",
    "value",
    "width",
    "autocapitalize",
    "autocorrect",
    "autofocus",
    "disabled",
    "form",
    "maxlength",
    "minlength",
    "placeholder",
    "readonly",
    "required",
    "selectionDirection",
    "spellcheck",
    "tabindex",
    "title",
  ],

  value: "",

  type: computed({
    get() {
      return "text";
    },

    set(_key, value) {
      let type = "text";

      if (canSetTypeOfInput(value)) {
        type = value;
      }

      return type;
    },
  }),

  size: null,

  pattern: null,

  min: null,

  max: null,

  placeholder: null,
  disabled: false,
  maxlength: null,

  init() {
    this._super(...arguments);
    this.on("paste", this, this._elementValueDidChange);
    this.on("cut", this, this._elementValueDidChange);
    this.on("input", this, this._elementValueDidChange);
  },

  bubbles: false,

  interpretKeyEvents(event) {
    let method = KEY_EVENTS[event.key];

    this._elementValueDidChange();
    if (method) {
      return this[method](event);
    }
  },

  _elementValueDidChange() {
    set(this, "value", this.element.value);
  },

  change(event) {
    this._elementValueDidChange(event);
  },

  insertNewline(event) {
    sendAction("enter", this, event);
    sendAction("insert-newline", this, event);
  },

  cancel(event) {
    sendAction("escape-press", this, event);
  },

  focusIn(event) {
    sendAction("focus-in", this, event);
  },

  focusOut(event) {
    this._elementValueDidChange(event);
    sendAction("focus-out", this, event);
  },

  keyPress(event) {
    sendAction("key-press", this, event);
  },

  keyUp(event) {
    this.interpretKeyEvents(event);
    sendAction("key-up", this, event);
  },

  keyDown(event) {
    sendAction("key-down", this, event);
  },
});

TextField.toString = () => "@ember/component/text-field";

export default TextField;
