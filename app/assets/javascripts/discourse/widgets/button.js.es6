import { createWidget } from 'discourse/widgets/widget';
import { iconNode } from 'discourse/helpers/fa-icon';

export default createWidget('button', {
  tagName: 'button.widget-button',

  buildClasses() {
    if (this.attrs.className) { return this.attrs.className; }
  },

  buildAttributes() {
    const attrs = this.attrs;

    let title;
    if (attrs.title) {
      title = I18n.t(attrs.title, attrs.titleOptions);
    } else if (attrs.label) {
      title = I18n.t(attrs.label, attrs.labelOptions);
    }

    const attributes = { "aria-label": title, title };
    if (attrs.disabled) { attributes.disabled = "true"; }

    if (attrs.data) {
      Object.keys(attrs.data).forEach(k => attributes[`data-${k}`] = attrs.data[k]);
    }

    return attributes;
  },

  html(attrs) {
    const contents = [];
    const left = !attrs.iconRight;
    if (attrs.icon && left) { contents.push(iconNode(attrs.icon, { class: attrs.iconClass })); }
    if (attrs.label) { contents.push(I18n.t(attrs.label, attrs.labelOptions)); }
    if (attrs.contents) { contents.push(attrs.contents); }
    if (attrs.icon && !left) { contents.push(iconNode(attrs.icon, { class: attrs.iconClass })); }

    return contents;
  },

  click(e) {
    const attrs = this.attrs;
    if (attrs.disabled) { return; }

    $(`button.widget-button`).removeClass('d-hover').blur();
    if (attrs.secondaryAction) {
      this.sendWidgetAction(attrs.secondaryAction);
    }

    if (attrs.sendActionEvent) {
      return this.sendWidgetAction(attrs.action, e);
    }
    return this.sendWidgetAction(attrs.action);
  }
});
