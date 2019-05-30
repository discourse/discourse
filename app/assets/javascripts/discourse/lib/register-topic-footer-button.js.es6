let _topicFooterButtons = {};

export function registerTopicFooterButton(button) {
  if (!button.id) {
    Ember.error(`Attempted to register a topic button: ${button} with no id.`);
    return;
  }

  if (_topicFooterButtons[button.id]) {
    return;
  }

  const defaultButton = {
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

    // is this button disaplyed in the mobile dropdown or as an inline button ?
    dropdown: false,

    // css class appended to the button
    classNames: [],

    // computed properties which should force a button state refresh
    // eg: ["topic.bookmarked", "topic.category_id"]
    dependentKeys: [],

    // should we display this button ?
    displayed: true,

    // is this button disabled ?
    disabled: false,

    // display order, higher comes first
    priority: 0
  };

  const normalizedButton = Object.assign(defaultButton, button);

  if (
    !normalizedButton.icon &&
    !normalizedButton.title &&
    !normalizedButton.translatedTitle
  ) {
    Ember.error(
      `Attempted to register a topic button: ${
        button.id
      } with no icon or title.`
    );
    return;
  }

  _topicFooterButtons[normalizedButton.id] = normalizedButton;
}

export function getTopicFooterButtons() {
  const dependentKeys = [].concat(
    ...Object.values(_topicFooterButtons)
      .map(tfb => tfb.dependentKeys)
      .filter(x => x)
  );

  const computedFunc = Ember.computed({
    get() {
      const _isFunction = descriptor =>
        descriptor && typeof descriptor === "function";

      const _compute = (button, property) => {
        const field = button[property];

        if (_isFunction(field)) {
          return field.apply(this);
        }

        return field;
      };

      return Object.values(_topicFooterButtons)
        .filter(button => _compute(button, "displayed"))
        .map(button => {
          const computedButon = {};

          computedButon.id = button.id;

          const label = _compute(button, "label");
          computedButon.label = label
            ? I18n.t(label)
            : _compute(button, "translatedLabel");

          const title = _compute(button, "title");
          computedButon.title = title
            ? I18n.t(title)
            : _compute(button, "translatedTitle");

          computedButon.classNames = (
            _compute(button, "classNames") || []
          ).join(" ");

          computedButon.icon = _compute(button, "icon");
          computedButon.disabled = _compute(button, "disabled");
          computedButon.dropdown = _compute(button, "dropdown");
          computedButon.priority = _compute(button, "priority");

          if (_isFunction(button.action)) {
            computedButon.action = () => button.action.apply(this);
          } else {
            const actionName = button.action;
            computedButon.action = () => this[actionName]();
          }

          return computedButon;
        })
        .sortBy("priority")
        .reverse();
    }
  });

  return computedFunc.property.apply(computedFunc, dependentKeys);
}

export function clearTopicFooterButtons() {
  _topicFooterButtons = [];
}
