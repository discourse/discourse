import Component from "@ember/component";
import { get, set, computed } from "@ember/object";
import Mixin from "@ember/object/mixin";
import { MUTABLE_CELL } from "@ember/-internals/views";
import { assert } from "@ember/debug";

const KEY_EVENTS = {
  Enter: "insertNewline",
  Escape: "cancel",
};

function getTarget(instance) {
  let target = get(instance, "target");
  if (target) {
    if (typeof target === "string") {
      let value = get(instance, target);
      if (value === undefined) {
        value = get(context.lookup, target);
      }

      return value;
    } else {
      return target;
    }
  }

  if (instance._target) {
    return instance._target;
  }

  return null;
}

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

  target: null,
  action: null,
  actionContext: null,

  actionContextObject: computed("actionContext", function () {
    let actionContext = get(this, "actionContext");

    if (typeof actionContext === "string") {
      return get(this, actionContext);
    } else {
      return actionContext;
    }
  }),

  triggerAction(opts = {}) {
    let { action, target, actionContext } = opts;
    action = action || get(this, "action");
    target = target || getTarget(this);

    if (actionContext === undefined) {
      actionContext = get(this, "actionContextObject") || this;
    }

    if (target && action) {
      let ret;

      if (target.send) {
        ret = target.send(...[action].concat(actionContext));
      } else {
        assert(
          `The action '${action}' did not exist on ${target}`,
          typeof target[action] === "function"
        );
        ret = target[action](...[].concat(actionContext));
      }

      if (ret !== false) {
        return true;
      }
    }

    return false;
  },
});

TextArea.toString = () => "@ember/component/text-area";

export default TextArea;
