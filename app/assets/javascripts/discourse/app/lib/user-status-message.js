import { DTooltip } from "discourse/lib/d-tooltip";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import { until } from "discourse/lib/formatter";
import User from "discourse/models/user";

export class UserStatusMessage {
  #dTooltip;

  constructor(status, opts) {
    this.html = this.#statusHtml(status, opts);
    this.#dTooltip = new DTooltip(this.html, this.#tooltipHtml(status));
  }

  destroy() {
    this.#dTooltip.destroy();
  }

  #emojiHtml(emojiName) {
    const emoji = escapeExpression(`:${emojiName}:`);
    return emojiUnescape(emoji, {
      skipTitle: true,
    });
  }

  #statusHtml(status, opts) {
    const html = document.createElement("span");
    html.classList.add("user-status-message");
    if (opts?.class) {
      html.classList.add(opts.class);
    }
    html.innerHTML = this.#emojiHtml(status.emoji);

    if (opts?.showDescription) {
      const description = document.createElement("span");
      description.classList.add("user-status-message-description");
      description.innerText = status.description;
      html.appendChild(description);
    }

    return html;
  }

  #tooltipHtml(status) {
    const html = document.createElement("div");
    html.classList.add("user-status-message-tooltip");
    html.innerHTML = this.#emojiHtml(status.emoji);

    const description = document.createElement("span");
    description.classList.add("user-status-tooltip-description");
    description.innerText = status.description;
    html.appendChild(description);

    if (status.ends_at) {
      const untilElement = document.createElement("div");
      untilElement.classList.add("user-status-tooltip-until");
      untilElement.innerText = this.#until(status.ends_at);
      html.appendChild(untilElement);
    }

    return html;
  }

  #until(endsAt) {
    const currentUser = User.current();

    const timezone = currentUser
      ? currentUser.user_option?.timezone
      : moment.tz.guess();

    return until(endsAt, timezone, currentUser?.locale);
  }
}
