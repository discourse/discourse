import { i18n } from "discourse-i18n";

let _chatComposerButtons = {};

export function registerChatComposerButton(button) {
  if (!button.id) {
    throw new Error("Attempted to register a chat composer button with no id.");
  }

  if (_chatComposerButtons[button.id]) {
    return;
  }

  const defaultButton = {
    id: null,
    action: null,
    icon: null,
    title: null,
    translatedTitle: null,
    label: null,
    translatedLabel: null,
    ariaLabel: null,
    translatedAriaLabel: null,
    position: "inline",
    classNames: [],
    dependentKeys: [],
    displayed: true,
    disabled: false,
    priority: 0,
  };

  const normalizedButton = Object.assign(defaultButton, button);

  if (
    !normalizedButton.icon &&
    !normalizedButton.label &&
    !normalizedButton.translatedLabel
  ) {
    throw new Error(
      `Attempted to register a chat composer button: ${button.id} with no icon or label.`
    );
  }

  _chatComposerButtons[normalizedButton.id] = normalizedButton;
}

function computeButton(context, button, property) {
  const field = button[property];

  if (isFunction(field)) {
    return field.apply(context);
  }

  return field;
}

function isFunction(descriptor) {
  return descriptor && typeof descriptor === "function";
}

export function chatComposerButtonsDependentKeys() {
  return [].concat(
    ...Object.values(_chatComposerButtons)
      .mapBy("dependentKeys")
      .filter(Boolean)
  );
}

export function chatComposerButtons(composer, position, context) {
  return Object.values(_chatComposerButtons)
    .filter((button) => {
      let valid =
        computeButton(composer, button, "displayed") &&
        computeButton(composer, button, "position") === position;

      if (button.context) {
        valid = valid && computeButton(composer, button, "context") === context;
      }

      return valid;
    })
    .map((button) => {
      const result = { id: button.id };

      const label = computeButton(composer, button, "label");
      result.label = label
        ? label
        : computeButton(composer, button, "translatedLabel");

      const ariaLabel = computeButton(composer, button, "ariaLabel");
      if (ariaLabel) {
        result.ariaLabel = i18n(ariaLabel);
      } else {
        const translatedAriaLabel = computeButton(
          composer,
          button,
          "translatedAriaLabel"
        );
        result.ariaLabel = translatedAriaLabel || result.label;
      }

      const title = computeButton(composer, button, "title");
      result.title = title
        ? i18n(title)
        : computeButton(composer, button, "translatedTitle");

      result.classNames = (
        computeButton(composer, button, "classNames") || []
      ).join(" ");

      result.icon = computeButton(composer, button, "icon");
      result.disabled = computeButton(composer, button, "disabled");
      result.priority = computeButton(composer, button, "priority");

      if (isFunction(button.action)) {
        result.action = () => {
          button.action.apply(composer, [context]);
        };
      } else {
        const actionName = button.action;
        result.action = () => {
          composer[actionName](context);
        };
      }

      return result;
    });
}

export function clearChatComposerButtons() {
  _chatComposerButtons = [];
}
