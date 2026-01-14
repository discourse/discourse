/* eslint-disable ember/no-classic-components */
import { MUTABLE_CELL } from "@ember/-internals/views";
import Component from "@ember/component";
import { get, set } from "@ember/object";

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

// eslint-disable-next-line ember/no-classic-classes
const TextArea = Component.extend({
  classNames: ["ember-text-area"],

  tagName: "textarea",
  attributeBindings: [
    "rows",
    "cols",
    "name",
    "selectionEnd",
    "selectionStart",
    "autocomplete",
    "wrap",
    "lang",
    "dir",
    "value",
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
  rows: null,
  cols: null,

  value: "",

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

TextArea.toString = () => "@ember/component/text-area";

export default TextArea;
