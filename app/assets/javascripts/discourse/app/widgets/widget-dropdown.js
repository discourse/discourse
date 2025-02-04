import { schedule } from "@ember/runloop";
import { createPopper } from "@popperjs/core";
import hbs from "discourse/widgets/hbs-compiler";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

/*

  widget-dropdown

  Usage
  -----

  {{attach
    widget="widget-dropdown"
    attrs=(hash
      id=id
      label=label
      content=content
      onChange=onChange
      options=(hash)
    )
  }}

  Mandatory attributes:

    - id: must be unique in the application

    - label or translatedLabel:
        - label: an i18n key to be translated and displayed on the header
        - translatedLabel: an already translated label to display on the header

    - onChange: action called when a click happens on a row, content[rowIndex] will be passed as params

  Optional attributes:

    - class: adds css class to the dropdown
    - content: list of items to display, if undefined or empty dropdown won't display
      Example content:

      ```
      [
        { id: 1, label: "foo.bar" },
        "separator",
        { id: 2, translatedLabel: "FooBar" },
        { id: 3 label: "foo.baz", icon: "xmark" },
        { id: 4, html: "<b>foo</b>" }
      ]
      ```

    - options: accepts a hash of optional attributes
      - headerClass: adds css class to the dropdown header
      - bodyClass: adds css class to the dropdown header
      - caret: adds a caret to visually enforce this is a dropdown
      - disabled: adds disabled css class and lock dropdown
*/

export const WidgetDropdownHeaderClass = {
  tagName: "button",

  transform(attrs) {
    return { label: this._buildLabel(attrs) };
  },

  buildAttributes(attrs) {
    return { title: this._buildLabel(attrs) };
  },

  buildClasses(attrs) {
    let classes = ["widget-dropdown-header", "btn", "btn-default"];
    if (attrs.class) {
      classes = classes.concat(attrs.class.split(" "));
    }
    return classes.filter(Boolean).join(" ");
  },

  click(event) {
    event.preventDefault();

    this.sendWidgetAction("_onTrigger");
  },

  template: hbs`
    {{#if attrs.icon}}
      {{d-icon attrs.icon}}
    {{/if}}
    <span class="label">
      {{transformed.label}}
    </span>
    {{#if attrs.caret}}
      {{d-icon "caret-down"}}
    {{/if}}
  `,

  _buildLabel(attrs) {
    return attrs.translatedLabel ? attrs.translatedLabel : i18n(attrs.label);
  },
};

createWidget("widget-dropdown-header", WidgetDropdownHeaderClass);

export const WidgetDropdownItemClass = {
  tagName: "div",

  transform(attrs) {
    return {
      content:
        attrs.item === "separator"
          ? "<hr>"
          : attrs.item.html
          ? attrs.item.html
          : attrs.item.translatedLabel
          ? attrs.item.translatedLabel
          : i18n(attrs.item.label),
    };
  },

  buildAttributes(attrs) {
    return {
      "data-id": attrs.item.id,
      tabindex: attrs.item === "separator" ? -1 : 0,
    };
  },

  buildClasses(attrs) {
    const classes = [
      "widget-dropdown-item",
      attrs.item === "separator" ? "separator" : `item-${attrs.item.id}`,
    ];
    classes.push(attrs.item.disabled ? "disabled" : "");
    return classes.join(" ");
  },

  keyDown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.sendWidgetAction("_onChange", this.attrs.item);
    }
  },

  click(event) {
    event.preventDefault();

    this.sendWidgetAction("_onChange", this.attrs.item);
  },

  template: hbs`
    {{#if attrs.item.icon}}
      {{d-icon attrs.item.icon}}
    {{/if}}
    {{{transformed.content}}}
  `,
};

createWidget("widget-dropdown-item", WidgetDropdownItemClass);

export const WidgetDropdownBodyClass = {
  tagName: "div",

  buildClasses(attrs) {
    return `widget-dropdown-body ${attrs.class || ""}`;
  },

  clickOutside() {
    this.sendWidgetAction("hideBody");
  },

  template: hbs`
    {{#each attrs.content as |item|}}
      {{attach
        widget="widget-dropdown-item"
        attrs=(hash item=item)
      }}
    {{/each}}
  `,
};

createWidget("widget-dropdown-body", WidgetDropdownBodyClass);

export const WidgetDropdownClass = {
  tagName: "div",

  init(attrs) {
    if (!attrs) {
      throw "A widget-dropdown expects attributes.";
    }

    if (!attrs.id) {
      throw "A widget-dropdown expects a unique `id` attribute.";
    }

    if (!attrs.label && !attrs.translatedLabel) {
      throw "A widget-dropdown expects at least a `label` or `translatedLabel`";
    }
  },

  buildKey: (attrs) => {
    return attrs.id;
  },

  buildAttributes(attrs) {
    return { id: attrs.id };
  },

  defaultState(attrs) {
    return {
      opened: false,
      disabled: (attrs.options && attrs.options.disabled) || false,
    };
  },

  buildClasses(attrs) {
    const classes = ["widget-dropdown"];
    classes.push(this.state.opened ? "opened" : "closed");
    classes.push(this.state.disabled ? "disabled" : "");
    return classes.join(" ") + " " + (attrs.class || "");
  },

  transform(attrs) {
    return {
      options: attrs.options || {},
      isDropdownVisible: !this.state.disabled && this.state.opened,
    };
  },

  hideBody() {
    this.state.opened = false;
  },

  _onChange(params) {
    if (params.disabled) {
      return;
    }
    this.state.opened = false;

    if (this.attrs.onChange) {
      if (typeof this.attrs.onChange === "string") {
        this.sendWidgetAction(this.attrs.onChange, params);
      } else {
        this.attrs.onChange(params);
      }
    }
  },

  destroy() {
    if (this._popper) {
      this._popper.destroy();
      this._popper = null;
    }
  },

  willRerenderWidget() {
    this._popper && this._popper.destroy();
  },

  didRenderWidget() {
    if (this.state.opened) {
      schedule("afterRender", () => {
        const dropdownHeader = document.querySelector(
          `#${this.attrs.id} .widget-dropdown-header`
        );

        if (!dropdownHeader) {
          return;
        }

        const dropdownBody = document.querySelector(
          `#${this.attrs.id} .widget-dropdown-body`
        );

        if (!dropdownBody) {
          return;
        }

        this._popper = createPopper(dropdownHeader, dropdownBody, {
          strategy: "absolute",
          placement: "bottom-start",
          modifiers: [
            {
              name: "preventOverflow",
            },
            {
              name: "offset",
              options: {
                offset: [0, 5],
              },
            },
          ],
        });
      });
    }
  },

  _onTrigger() {
    this.state.opened = !this.state.opened;
  },

  template: hbs`
    {{#if attrs.content}}
      {{attach
        widget="widget-dropdown-header"
        attrs=(hash
          icon=attrs.icon
          label=attrs.label
          translatedLabel=attrs.translatedLabel
          class=this.transformed.options.headerClass
          caret=this.transformed.options.caret
        )
      }}

      {{#if this.transformed.isDropdownVisible}}
        {{attach
          widget="widget-dropdown-body"
          attrs=(hash
            id=attrs.id
            class=this.transformed.options.bodyClass
            content=attrs.content
          )
        }}
      {{/if}}
    {{/if}}
  `,
};

export default createWidget("widget-dropdown", WidgetDropdownClass);
