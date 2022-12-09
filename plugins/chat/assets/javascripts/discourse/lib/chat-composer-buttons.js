import I18n from "I18n";

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

export function chatComposerButtons(context, position) {
  return Object.values(_chatComposerButtons)
    .filter(
      (button) =>
        computeButton(context, button, "displayed") &&
        computeButton(context, button, "position") === position
    )
    .map((button) => {
      const result = { id: button.id };

      const label = computeButton(context, button, "label");
      result.label = label
        ? label
        : computeButton(context, button, "translatedLabel");

      const ariaLabel = computeButton(context, button, "ariaLabel");
      if (ariaLabel) {
        result.ariaLabel = I18n.t(ariaLabel);
      } else {
        const translatedAriaLabel = computeButton(
          context,
          button,
          "translatedAriaLabel"
        );
        result.ariaLabel = translatedAriaLabel || result.label;
      }

      const title = computeButton(context, button, "title");
      result.title = title
        ? I18n.t(title)
        : computeButton(context, button, "translatedTitle");

      result.classNames = (
        computeButton(context, button, "classNames") || []
      ).join(" ");

      result.icon = computeButton(context, button, "icon");
      result.disabled = computeButton(context, button, "disabled");
      result.priority = computeButton(context, button, "priority");

      if (isFunction(button.action)) {
        result.action = () => {
          button.action.apply(context);
        };
      } else {
        const actionName = button.action;
        result.action = () => {
          context[actionName]();
        };
      }

      return result;
    });
}

export function clearChatComposerButtons() {
  _chatComposerButtons = [];
}
