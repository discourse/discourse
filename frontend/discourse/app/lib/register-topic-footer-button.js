import { i18n } from "discourse-i18n";

let _topicFooterButtons = {};

export function registerTopicFooterButton(button) {
  if (!button.id) {
    throw new Error(`Attempted to register a topic button with no id.`);
  }

  if (_topicFooterButtons[button.id]) {
    return;
  }

  const defaultButton = {
    type: "inline-button",

    // id of the button, required
    id: null,

    // icon displayed on the button
    icon: null,

    // local key path for title attribute
    title: null,
    translatedTitle: null,

    // local key path for label
    label: null,
    translatedLabel: null,

    // local key path for aria label
    ariaLabel: null,
    translatedAriaLabel: null,

    // is this button displayed in the mobile dropdown or as an inline button ?
    dropdown: false,

    // css class appended to the button
    classNames: [],

    // discourseComputed properties which should force a button state refresh
    // eg: ["topic.bookmarked", "topic.category_id"]
    dependentKeys: [],

    // should we display this button ?
    displayed: true,

    // is this button disabled ?
    disabled: false,

    // display order, higher comes first
    priority: 0,

    // is this button displayed for anonymous users ?
    anonymousOnly: false,
  };

  const normalizedButton = Object.assign(defaultButton, button);

  if (
    !normalizedButton.icon &&
    !normalizedButton.title &&
    !normalizedButton.translatedTitle
  ) {
    throw new Error(
      `Attempted to register a topic button: ${button.id} with no icon or title.`
    );
  }

  _topicFooterButtons[normalizedButton.id] = normalizedButton;
}

export function getTopicFooterButtons(context) {
  const legacyDependentKeys = [].concat(
    ...Object.values(_topicFooterButtons)
      .map((tfb) => tfb.dependentKeys)
      .filter((x) => x)
  );

  legacyDependentKeys.forEach((k) => context.get(k));

  const _isFunction = (descriptor) =>
    descriptor && typeof descriptor === "function";

  const _compute = (button, property) => {
    const field = button[property];

    if (_isFunction(field)) {
      return field.apply(context);
    }

    return field;
  };

  return Object.values(_topicFooterButtons)
    .filter((button) => _compute(button, "displayed"))
    .map((button) => {
      return {
        id: button.id,
        type: button.type,
        get label() {
          const label = _compute(button, "label");
          return label ? i18n(label) : _compute(button, "translatedLabel");
        },
        get ariaLabel() {
          const ariaLabel = _compute(button, "ariaLabel");
          if (ariaLabel) {
            return i18n(ariaLabel);
          } else {
            const translatedAriaLabel = _compute(button, "translatedAriaLabel");
            return translatedAriaLabel || this.label;
          }
        },
        get title() {
          const title = _compute(button, "title");
          return title ? i18n(title) : _compute(button, "translatedTitle");
        },
        get classNames() {
          return (_compute(button, "classNames") || []).join(" ");
        },
        get icon() {
          return _compute(button, "icon");
        },
        get disabled() {
          return _compute(button, "disabled");
        },
        get dropdown() {
          return _compute(button, "dropdown");
        },
        get priority() {
          return _compute(button, "priority");
        },
        get anonymousOnly() {
          return _compute(button, "anonymousOnly");
        },
        get action() {
          if (_isFunction(button.action)) {
            return () => button.action.apply(context);
          } else {
            const actionName = button.action;
            return () => context[actionName]();
          }
        },
      };
    });
}

export function clearTopicFooterButtons() {
  _topicFooterButtons = [];
}
