let _topicFooterDropdowns = {};

export function registerTopicFooterDropdown(dropdown) {
  if (!dropdown.id) {
    throw new Error(`Attempted to register a topic dropdown with no id.`);
  }

  if (_topicFooterDropdowns[dropdown.id]) {
    return;
  }

  const defaultDropdown = {
    type: "inline-dropdown",

    // id of the dropdown, required
    id: null,

    // icon displayed on the dropdown
    icon: null,

    // dropdown’s content
    content: null,

    // css class appended to the button
    classNames: [],

    // discourseComputed properties which should force a button state refresh
    // eg: ["topic.bookmarked", "topic.category_id"]
    dependentKeys: [],

    // should we display this dropdown ?
    displayed: true,

    // is this button disabled ?
    disabled: false,

    // display order, higher comes first
    priority: 0,

    // an object used to display the state of the dropdown
    // when no value is currently set, eg: { id: 1, name: "foo" }
    noneItem: null,
  };

  const normalizedDropdown = Object.assign(defaultDropdown, dropdown);

  if (!normalizedDropdown.content) {
    throw new Error(
      `Attempted to register a topic dropdown: ${dropdown.id} with no content.`
    );
  }

  _topicFooterDropdowns[normalizedDropdown.id] = normalizedDropdown;
}

export function getTopicFooterDropdowns(context) {
  const legacyDependentKeys = [].concat(
    ...Object.values(_topicFooterDropdowns)
      .map((item) => item.dependentKeys)
      .filter(Boolean)
  );
  legacyDependentKeys.forEach((key) => context.get(key));

  const _isFunction = (descriptor) =>
    descriptor && typeof descriptor === "function";

  const _compute = (dropdown, property) => {
    const field = dropdown[property];

    if (_isFunction(field)) {
      return field.apply(context);
    }

    return field;
  };

  return Object.values(_topicFooterDropdowns)
    .filter((dropdown) => _compute(dropdown, "displayed"))
    .map((dropdown) => {
      return {
        id: dropdown.id,
        type: dropdown.type,
        get classNames() {
          return (_compute(dropdown, "classNames") || []).join(" ");
        },
        get icon() {
          return _compute(dropdown, "icon");
        },
        get disabled() {
          return _compute(dropdown, "disabled");
        },
        get priority() {
          return _compute(dropdown, "priority");
        },
        get content() {
          return _compute(dropdown, "content");
        },
        get value() {
          return _compute(dropdown, "value");
        },
        get action() {
          return dropdown.action;
        },
        get noneItem() {
          return _compute(dropdown, "noneItem");
        },
      };
    });
}

export function clearTopicFooterDropdowns() {
  _topicFooterDropdowns = {};
}
