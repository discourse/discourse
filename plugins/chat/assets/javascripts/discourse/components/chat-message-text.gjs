import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import { i18n } from "discourse-i18n";
import { isCollapsible } from "discourse/plugins/chat/discourse/components/chat-message-collapser";
import ChatMessageCollapser from "./chat-message-collapser";

// Match data-base62-sha1 attribute values in cooked HTML — used to suppress
// the upload widget tile for uploads already rendered inline by the cooker.
// Regex is cheap vs. Nokogiri-style DOM parsing per message.
const INLINE_BASE62_SHA1_RE = /data-base62-sha1="([^"]+)"/g;

function inlineUploadSha1s(cooked) {
  const set = new Set();
  if (!cooked) {
    return set;
  }
  for (const m of cooked.matchAll(INLINE_BASE62_SHA1_RE)) {
    set.add(m[1]);
  }
  return set;
}

export default class ChatMessageText extends Component {
  get isEdited() {
    return this.args.edited ?? false;
  }

  // Uploads still rendered separately by the collapser: any upload whose sha1
  // is NOT already inline in cooked. message.uploads stays unfiltered for the
  // edit flow (chat-channel.gjs reads it to build upload_ids on save).
  get widgetUploads() {
    if (!this.args.uploads?.length) {
      return this.args.uploads;
    }
    const inline = inlineUploadSha1s(this.args.cooked);
    if (!inline.size) {
      return this.args.uploads;
    }
    return this.args.uploads.filter((u) => {
      const sha1 = extractBase62FromShortUrl(u.short_url);
      return !sha1 || !inline.has(sha1);
    });
  }

  get isCollapsible() {
    return isCollapsible(this.args.cooked, this.widgetUploads);
  }

  <template>
    <div class="chat-message-text">
      {{#if this.isCollapsible}}
        <ChatMessageCollapser
          @cooked={{@cooked}}
          @decorate={{@decorate}}
          @uploads={{this.widgetUploads}}
          @onToggleCollapse={{@onToggleCollapse}}
        />
      {{else}}
        <DDecoratedHtml
          @html={{trustHTML @cooked}}
          @decorate={{@decorate}}
          @className="chat-cooked"
        />
      {{/if}}

      {{#if this.isEdited}}
        <span class="chat-message-edited">({{i18n "chat.edited"}})</span>
      {{/if}}

      {{yield}}
    </div>
  </template>
}

function extractBase62FromShortUrl(shortUrl) {
  const m = shortUrl?.match(/^upload:\/\/([a-zA-Z0-9]+)/);
  return m?.[1] ?? null;
}
