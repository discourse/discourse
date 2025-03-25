import getURL from "discourse/lib/get-url";
import { emojiUnescape } from "discourse/lib/text";
import { i18n } from "discourse-i18n";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    chat: {
      attrs: {
        messageId: {},
        username: {},
        datetime: {},
        channelName: {},
        channelId: {},
        html: {},
        rawContent: {},
        multiQuote: {},
        chained: {},
        threadId: { default: null },
        threadTitle: { default: null },
        threadHtml: { default: null },
      },
      group: "block",
      isolating: true,
      selectable: true,
      parseDOM: [{ tag: "div.chat-transcript" }],
      toDOM(node) {
        // NOTE: This HTML representation of the node in a lot of ways is duplicated from
        // the chat transcript markdown-it rule, this is unavoidable unless we completely
        // decouple the token generation from the HTML generation, which is a lot of work,
        // so this is acceptable for now.

        const wrapperElement = document.createElement("div");
        wrapperElement.classList.add("chat-transcript");

        if (node.attrs.chained) {
          wrapperElement.classList.add("chat-transcript-chained");
        }

        let metaElement;
        let channelLinkElement;
        if (node.attrs.channelName) {
          if (node.attrs.multiQuote) {
            metaElement = document.createElement("div");
            metaElement.classList.add("chat-transcript-meta");

            const channelLink = node.attrs.channelId
              ? getURL(`/chat/c/-/${node.attrs.channelId}`)
              : null;

            metaElement.innerHTML = i18n("chat.quote.original_channel", {
              channel: emojiUnescape(node.attrs.channelName),
              channelLink,
            });
          } else {
            channelLinkElement = document.createElement("a");
            channelLinkElement.classList.add("chat-transcript-channel");
            channelLinkElement.href = getURL(
              `/chat/c/-/${node.attrs.channelId}`
            );
            channelLinkElement.innerHTML = `#${emojiUnescape(
              node.attrs.channelName
            )}`;
          }
        }

        const userElement = document.createElement("div");
        userElement.classList.add("chat-transcript-user");

        // TODO (martin) Need to use current user's timezone here when we have
        // that available.
        const formattedDateTime = moment(node.attrs.datetime).format(
          i18n("dates.long_no_year")
        );
        userElement.innerHTML = `
          <span class="chat-transcript-username">${node.attrs.username}</span>
          <span class="chat-transcript-datetime">${formattedDateTime}</span>
        `;

        const messagesElement = document.createElement("div");
        messagesElement.classList.add("chat-transcript-messages");
        messagesElement.innerHTML = node.attrs.html;

        if (metaElement) {
          wrapperElement.appendChild(metaElement);
        }

        if (node.attrs.threadId) {
          const threadDetailsElement = document.createElement("details");
          const threadSummaryElement = document.createElement("summary");

          const threadElement = document.createElement("div");
          threadElement.classList.add("chat-transcript-thread");

          const threadHeaderElement = document.createElement("div");
          threadHeaderElement.classList.add("chat-transcript-thread-header");
          threadHeaderElement.innerHTML = `
          <svg class="fa d-icon d-icon-discourse-threads svg-icon svg-node">
            <use href="#discourse-threads"></use>
          </svg>`;

          const threadTitleElement = document.createElement("span");
          threadTitleElement.classList.add(
            "chat-transcript-thread-header__title"
          );
          threadTitleElement.innerHTML = node.attrs.threadTitle
            ? emojiUnescape(node.attrs.threadTitle)
            : i18n("chat.quote.default_thread_title");

          threadHeaderElement.appendChild(threadTitleElement);
          threadElement.appendChild(threadHeaderElement);
          threadElement.appendChild(userElement);

          if (channelLinkElement) {
            userElement.appendChild(channelLinkElement);
          }

          threadElement.appendChild(messagesElement);
          threadSummaryElement.appendChild(threadElement);
          threadDetailsElement.appendChild(threadSummaryElement);

          if (node.attrs.threadHtml) {
            threadDetailsElement.innerHTML += node.attrs.threadHtml;
          }

          wrapperElement.appendChild(threadDetailsElement);
        } else {
          wrapperElement.appendChild(userElement);

          if (channelLinkElement) {
            userElement.appendChild(channelLinkElement);
          }

          wrapperElement.appendChild(messagesElement);
        }

        return wrapperElement;
      },
    },
  },
  serializeNode: {
    chat(state, node) {
      const bbCodeAttrs = [];
      bbCodeAttrs.push(
        `quote="${node.attrs.username};${node.attrs.messageId};${node.attrs.datetime}"`
      );
      bbCodeAttrs.push(`channel="${node.attrs.channelName}"`);
      bbCodeAttrs.push(`channelId="${node.attrs.channelId}"`);

      if (node.attrs.chained) {
        bbCodeAttrs.push(`chained="true"`);
      }

      if (node.attrs.multiQuote) {
        bbCodeAttrs.push(`multiQuote="true"`);
      }

      state.write(`[chat ${bbCodeAttrs.join(" ")}]\n`);

      state.write(node.attrs.rawContent);
      state.write("\n[/chat]\n");
    },
  },
  parse: {
    div_chat_transcript_wrap_open(state, token, tokens, i) {
      // The slice here makes sure we get the html_raw content
      // only for the current [chat] bbcode block based on the
      // token index.
      const nextHtmlRaw = tokens
        .slice(i)
        .find((t) => t.type === "html_raw" && t.nesting === 1);
      const messagesHtml = nextHtmlRaw?.content;

      let threadHtmlRaw;
      if (token.attrGet("data-thread-id")) {
        threadHtmlRaw = tokens
          .slice(tokens.indexOf(nextHtmlRaw) + 1)
          .find((t) => t.type === "html_raw" && t.nesting === 1);
      }

      // So this content and the whole wrap_open happens for every single instance of
      // the `[chat]` bbcode, including nested which is the case for threads.
      //
      // Only the first one will have multiQuote and chained
      //
      // Multiquote is > 1 message
      // Chained is > 1 message by different users
      state.openNode(state.schema.nodes.chat, {
        messageId: token.attrGet("data-message-id"),
        username: token.attrGet("data-username"),
        datetime: token.attrGet("data-datetime"),
        channelName: token.attrGet("data-channel-name"),
        channelId: token.attrGet("data-channel-id"),
        chained: token.attrGet("data-chained"),
        multiQuote: token.attrGet("data-multiquote"),
        threadId: token.attrGet("data-thread-id"),
        threadTitle: token.attrGet("data-thread-title"),
        threadHtml: threadHtmlRaw ? threadHtmlRaw.content : null,
        html: messagesHtml,
        rawContent: token.content,
      });
      return true;
    },
    div_chat_transcript_wrap_close(state) {
      state.closeNode();
      return true;
    },
    div_chat_transcript_user: { ignore: true },
    div_chat_transcript_user_avatar: { ignore: true },
    div_chat_transcript_username: { ignore: true },
    div_chat_transcript_datetime: { ignore: true },
    div_chat_transcript_messages: { ignore: true },
    div_chat_transcript_reaction: { ignore: true },

    // Reaction-related tokens are not used in the live preview,
    // they are only used when archiving a channel, not needed here.
    div_chat_transcript_reactions: { ignore: true },
    div_chat_transcript_meta: { ignore: true },

    // Thread-related tokens
    details_chat_transcript_wrap: { ignore: true },
    summary_chat_transcript: { ignore: true },
    div_thread: { ignore: true },
    div_thread_header: { ignore: true },
    svg_thread_header: { ignore: true },
    use_svg_thread: { ignore: true },
    span_thread_title: { ignore: true },

    html_raw: { ignore: true, noCloseToken: true },

    span: { ignore: true },
    span_open() {
      // TODO: not sure if i need to actually do anything here,
      // its just here to stop it erroring, otherwise I get
      //
      // No parser processed span_open token for tag: span, attrs: [["title","2025-03-20T07:12:57Z"]]
      return true;
    },
    span_close() {
      return true;
    },
  },
};

export default extension;
