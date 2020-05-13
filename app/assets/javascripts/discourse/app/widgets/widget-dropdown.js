import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { schedule } from "@ember/runloop";
import hbs from "discourse/widgets/hbs-compiler";

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
        { id: 3 label: "foo.baz", icon: "times" },
        { id: 4, html: "<b>foo</b>" }
      ]
      ```

    - options: accepts a hash of optional attributes
      - headerClass: adds css class to the dropdown header
      - bodyClass: adds css class to the dropdown header
      - caret: adds a caret to visually enforce this is a dropdown
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
    return attrs.translatedLabel ? attrs.translatedLabel : I18n.t(attrs.label);
  }
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
          : I18n.t(attrs.item.label)
    };
  },

  buildAttributes(attrs) {
    return { "data-id": attrs.item.id };
  },

  buildClasses(attrs) {
    return [
      "widget-dropdown-item",
      attrs.item === "separator" ? "separator" : `item-${attrs.item.id}`
    ].join(" ");
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
  `
};

createWidget("widget-dropdown-item", WidgetDropdownItemClass);

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

  buildKey: attrs => {
    return attrs.id;
  },

  buildAttributes(attrs) {
    return { id: attrs.id };
  },

  defaultState() {
    return {
      opened: false
    };
  },

  buildClasses(attrs) {
    const classes = ["widget-dropdown"];
    classes.push(this.state.opened ? "opened" : "closed");
    return classes.join(" ") + " " + (attrs.class || "");
  },

  transform(attrs) {
    const options = attrs.options || {};

    return {
      options,
      bodyClass: `widget-dropdown-body ${options.bodyClass || ""}`
    };
  },

  clickOutside() {
    this.state.opened = false;
    this.scheduleRerender();
  },

  _onChange(params) {
    this.state.opened = false;
    if (this.attrs.onChange) {
      if (typeof this.attrs.onChange === "string") {
        this.sendWidgetAction(this.attrs.onChange, params);
      } else {
        this.attrs.onChange(params);
      }
    }
  },

  _onTrigger() {
    if (this.state.opened) {
      this.state.opened = false;
      this._closeDropdown(this.attrs.id);
    } else {
      this.state.opened = true;
      this._openDropdown(this.attrs.id);
    }

    this._popper && this._popper.update();
  },

  destroy() {
    if (this._popper) {
      this._popper.destroy();
      this._popper = null;
    }
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

      <div class={{transformed.bodyClass}}>
        {{#each attrs.content as |item|}}
          {{attach
            widget="widget-dropdown-item"
            attrs=(hash item=item)
          }}
        {{/each}}
      </div>
    {{/if}}
  `,

  _closeDropdown() {
    this._popper && this._popper.destroy();
  },

  _openDropdown(id) {
    const dropdownHeader = document.querySelector(
      `#${id} .widget-dropdown-header`
    );
    const dropdownBody = document.querySelector(`#${id} .widget-dropdown-body`);

    if (dropdownHeader && dropdownBody) {
      /* global Popper:true */
      this._popper = Popper.createPopper(dropdownHeader, dropdownBody, {
        strategy: "fixed",
        placement: "bottom-start",
        modifiers: [
          {
            name: "preventOverflow"
          },
          {
            name: "offset",
            options: {
              offset: [0, 5]
            }
          }
        ]
      });
    }

    schedule("afterRender", () => {
      this._popper && this._popper.update();
    });
  }
};

export default createWidget("widget-dropdown", WidgetDropdownClass);
