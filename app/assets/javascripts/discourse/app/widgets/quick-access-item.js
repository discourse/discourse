import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { h } from "@discourse/virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";

/**
 * This helper widget tries to enforce a consistent look and behavior for any
 * item under any quick access panels.
 *
 * It accepts the following attributes:
 *   action
 *   actionParam
 *   content
 *   escapedContent
 *   href
 *   icon
 *   read
 *   username
 */
export default createWidget("quick-access-item", {
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

  html({ href, title, icon }) {
    let content = this._contentHtml();

    if (href) {
      let topicId = href.match(/\/t\/.*?\/(\d+)/);
      if (topicId && topicId[1]) {
        topicId = escapeExpression(topicId[1]);
        content = `<span data-topic-id="${topicId}">${content}</span>`;
      }
    }

    return h("a", { attributes: this._linkAttributes(href, title) }, [
      iconNode(icon),
      new RawHtml({
        html: `<div>${this._usernameHtml()}${content}</div>`,
      }),
    ]);
  },

  click(e) {
    this.attrs.read = true;
    if (this.attrs.action) {
      e.preventDefault();
      return this.sendWidgetAction(this.attrs.action, this.attrs.actionParam);
    }
  },

  _linkAttributes(href, title) {
    return { href, title };
  },

  _contentHtml() {
    const content =
      this.attrs.escapedContent || escapeExpression(this.attrs.content);
    return emojiUnescape(content);
  },

  _usernameHtml() {
    // Generate an empty `<span>` even if there is no username, because the
    // first `<span>` is styled differently.
    return this.attrs.username
      ? `<span>${this.attrs.username}</span> `
      : "<span></span>";
  },
});
