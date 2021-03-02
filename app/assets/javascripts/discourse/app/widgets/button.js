import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";

export const ButtonClass = {
  tagName: "button.widget-button.btn",

  buildClasses(attrs) {
    let className = this.attrs.className || "";

    let hasText = attrs.label || attrs.contents;

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

  buildId(attrs) {
    return attrs.id;
  },

  buildAttributes() {
    const attrs = this.attrs;
    const attributes = {};
    let title = attrs.translatedTitle;

    if (!title && attrs.title) {
      title = I18n.t(attrs.title, attrs.titleOptions);
    }

    if (title) {
      attributes["aria-label"] = title;
      attributes.title = title;
    }

    if (attrs.role) {
      attributes["role"] = attrs.role;
    }

    if (attrs.tabAttrs) {
      const tab = attrs.tabAttrs;
      attributes["aria-selected"] = tab["aria-selected"];
      attributes["tabindex"] = tab["tabindex"];
      attributes["aria-controls"] = tab["aria-controls"];
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
      icon.properties.attributes["aria-hidden"] = true;
    }
    return icon;
  },

  html(attrs) {
    const contents = [];
    const left = !attrs.iconRight;
    if (attrs.icon && left) {
      contents.push(this._buildIcon(attrs));
    }
    if (attrs.label) {
      contents.push(
        h("span.d-button-label", I18n.t(attrs.label, attrs.labelOptions))
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
  jQuery.extend(ButtonClass, {
    tagName: "button.widget-button.btn-flat",
  })
);
