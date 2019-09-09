import { h } from "virtual-dom";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { emojiUnescape } from "discourse/lib/text";
import { iconNode } from "discourse-common/lib/icon-library";

createWidget("quick-access-item", {
  tagName: "li",

  buildClasses(attrs) {
    const result = [];
    if (attrs.className) {
      result.push(attrs.className);
    }
    if (attrs.read === undefined || attrs.read) {
      result.push("read");
    }
    return result;
  },

  html({ icon, href, content }) {
    return h("a", { attributes: { href } }, [
      iconNode(icon),
      new RawHtml({
        html: `<div>${this._usernameHtml()}${emojiUnescape(
          Handlebars.Utils.escapeExpression(content)
        )}</div>`
      })
    ]);
  },

  click(e) {
    this.attrs.read = true;
    if (this.attrs.action) {
      e.preventDefault();
      return this.sendWidgetAction(this.attrs.action, this.attrs.actionParam);
    }
  },

  _usernameHtml() {
    return this.attrs.username ? `<span>${this.attrs.username}</span> ` : "";
  }
});
