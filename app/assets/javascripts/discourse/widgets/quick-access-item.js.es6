import { h } from "virtual-dom";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";
import { emojiUnescape } from "discourse/lib/text";
import { iconNode } from "discourse-common/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";

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

  html({ href, icon }) {
    let content = this._contentHtml();

    if (href) {
      let topicId = href.match(/\/t\/.*?\/(\d+)/);
      if (topicId && topicId[1]) {
        topicId = escapeExpression(topicId[1]);
        content = `<span data-topic-id="${topicId}">${content}</span>`;
      }
    }

    return h("a", { attributes: { href } }, [
      iconNode(icon),
      new RawHtml({
        html: `<div>${this._usernameHtml()}${content}</div>`
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
  }
});
