import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import DiscourseURL from "discourse/lib/url";

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

  buildAttributes() {
    const attrs = this.attrs;
    const attributes = {};

    if (attrs.title) {
      const title = I18n.t(attrs.title, attrs.titleOptions);
      attributes["aria-label"] = title;
      attributes.title = title;
    }

    if (attrs.disabled) {
      attributes.disabled = "true";
    }

    if (attrs.data) {
      Object.keys(attrs.data).forEach(
        k => (attributes[`data-${k}`] = attrs.data[k])
      );
    }

    return attributes;
  },

  html(attrs) {
    const contents = [];
    const left = !attrs.iconRight;
    if (attrs.icon && left) {
      contents.push(iconNode(attrs.icon, { class: attrs.iconClass }));
    }
    if (attrs.label) {
      contents.push(
        h("span.d-button-label", I18n.t(attrs.label, attrs.labelOptions))
      );
    }
    if (attrs.contents) {
      contents.push(attrs.contents);
    }
    if (attrs.icon && !left) {
      contents.push(iconNode(attrs.icon, { class: attrs.iconClass }));
    }

    return contents;
  },

  click(e) {
    const attrs = this.attrs;
    if (attrs.disabled) {
      return;
    }

    $(`button.widget-button`)
      .removeClass("d-hover")
      .blur();
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
  }
};

export default createWidget("button", ButtonClass);

createWidget(
  "flat-button",
  jQuery.extend(ButtonClass, {
    tagName: "button.widget-button.btn-flat"
  })
);
