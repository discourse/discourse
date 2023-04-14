import { computed } from "@ember/object";

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

export function getTopicFooterDropdowns() {
  const dependentKeys = [].concat(
    ...Object.values(_topicFooterDropdowns)
      .mapBy("dependentKeys")
      .filter(Boolean)
  );

  return computed(...dependentKeys, {
    get() {
      const _isFunction = (descriptor) =>
        descriptor && typeof descriptor === "function";

      const _compute = (dropdown, property) => {
        const field = dropdown[property];

        if (_isFunction(field)) {
          return field.apply(this);
        }

        return field;
      };

      return Object.values(_topicFooterDropdowns)
        .filter((dropdown) => _compute(dropdown, "displayed"))
        .map((dropdown) => {
          const discourseComputedDropdown = {};

          discourseComputedDropdown.id = dropdown.id;
          discourseComputedDropdown.type = dropdown.type;

          discourseComputedDropdown.classNames = (
            _compute(dropdown, "classNames") || []
          ).join(" ");

          discourseComputedDropdown.icon = _compute(dropdown, "icon");
          discourseComputedDropdown.disabled = _compute(dropdown, "disabled");
          discourseComputedDropdown.priority = _compute(dropdown, "priority");
          discourseComputedDropdown.content = _compute(dropdown, "content");
          discourseComputedDropdown.value = _compute(dropdown, "value");
          discourseComputedDropdown.action = dropdown.action;
          discourseComputedDropdown.noneItem = _compute(dropdown, "noneItem");

          return discourseComputedDropdown;
        });
    },
  });
}

export function clearTopicFooterDropdowns() {
  _topicFooterDropdowns = {};
}
