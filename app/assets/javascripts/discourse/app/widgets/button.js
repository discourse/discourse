import $ from "jquery";
import { h } from "virtual-dom";
import DiscourseURL from "discourse/lib/url";
import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { i18n } from "discourse-i18n";

export const ButtonClass = {
  tagName: "button.widget-button.btn",

  buildClasses(attrs) {
    let className = this.attrs.className || "";

    let hasText = attrs.translatedLabel || attrs.label || attrs.contents;

    if (!hasText) {
      className += " no-text";
    }

    if (attrs.icon) {
      className += " btn-icon";
      if (hasText) {
        className += "-text";
      }
    } else if (hasText) {
      className += " btn-text";
    }

    return className;
  },

  buildAttributes() {
    const attrs = this.attrs;
    const attributes = {};
    let title = attrs.translatedTitle;

    if (!title && attrs.title) {
      title = i18n(attrs.title, attrs.titleOptions);
    }

    if (title) {
      attributes.title = title;
    }

    if (attrs.role) {
      attributes["role"] = attrs.role;
    }

    if (attrs.translatedAriaLabel) {
      attributes["aria-label"] = attrs.translatedAriaLabel;
    }

    if (attrs.ariaExpanded) {
      attributes["aria-expanded"] = attrs.ariaExpanded;
    }

    if (attrs.ariaControls) {
      attributes["aria-controls"] = attrs.ariaControls;
    }

    if (attrs.ariaPressed) {
      attributes["aria-pressed"] = attrs.ariaPressed;
    }

    if (attrs.ariaLive) {
      attributes["aria-live"] = attrs.ariaLive;
    }

    if (attrs.tabAttrs) {
      const tab = attrs.tabAttrs;
      attributes["aria-selected"] = tab["aria-selected"];
      attributes["tabindex"] = tab["tabindex"];
      attributes["aria-controls"] = tab["aria-controls"];
      attributes["id"] = attrs.id;
    }

    if (attrs.disabled) {
      attributes.disabled = "true";
    }

    if (attrs.data) {
      Object.keys(attrs.data).forEach(
        (k) => (attributes[`data-${k}`] = attrs.data[k])
      );
    }

    return attributes;
  },

  _buildIcon(attrs) {
    const icon = iconNode(attrs.icon, { class: attrs.iconClass });
    if (attrs["aria-label"]) {
      icon.properties.attributes["role"] = "img";
      icon.properties.attributes["aria-hidden"] = false;
    }
    return icon;
  },

  html(attrs) {
    const contents = [];
    const left = !attrs.iconRight;

    if (attrs.icon && left) {
      contents.push(this._buildIcon(attrs));
    }
    if (attrs.emoji && left) {
      contents.push(this.attach("emoji", { name: attrs.emoji }));
    }
    if (attrs.label) {
      contents.push(
        h("span.d-button-label", i18n(attrs.label, attrs.labelOptions))
      );
    }
    if (attrs.translatedLabel) {
      contents.push(
        h(
          "span.d-button-label",
          attrs.translatedLabel.toString(),
          attrs.translatedLabelOptions
        )
      );
    }
    if (attrs.contents) {
      contents.push(attrs.contents);
    }
    if (attrs.emoji && !left) {
      contents.push(this.attach("emoji", { name: attrs.emoji }));
    }
    if (attrs.icon && !left) {
      contents.push(this._buildIcon(attrs));
    }

    return contents;
  },

  click(e) {
    const attrs = this.attrs;
    if (attrs.disabled) {
      return;
    }

    $(`button.widget-button`).removeClass("d-hover").blur();
    if (attrs.secondaryAction) {
      this.sendWidgetAction(attrs.secondaryAction);
    }

    if (attrs.url) {
      return DiscourseURL.routeTo(attrs.url);
    }

    if (attrs.sendActionEvent) {
      return this.sendWidgetAction(attrs.action, e);
    }
    return this.sendWidgetAction(attrs.action, attrs.actionParam);
  },
};

export default createWidget("button", ButtonClass);

createWidget(
  "flat-button",
  Object.assign(ButtonClass, {
    tagName: "button.widget-button.btn-flat",
  })
);
