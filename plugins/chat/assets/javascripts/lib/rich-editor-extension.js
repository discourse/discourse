import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

// need to account for both one message from single user,
// multiple messages from single user,
// and multiple messages from multiple users
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

        const wrapper = document.createElement("div");
        wrapper.classList.add("chat-transcript");

        let metaElement;
        if (node.attrs.multiQuote) {
          metaElement = document.createElement("div");
          metaElement.classList.add("chat-transcript-meta");

          const channelLink = node.attrs.channelId
            ? getURL(`/chat/c/-/${node.attrs.channelId}`)
            : null;

          // TODO (martin) Handle emoji unescaping of channel name
          metaElement.innerHTML = i18n("chat.quote.original_channel", {
            channel: node.attrs.channelName,
            channelLink,
          });
        }

        const userElement = document.createElement("div");
        userElement.classList.add("chat-transcript-user");

        // TODO (martin) Handle reactions...do we care about showing them here?
        // TODO (martin) Handle threads
        // TODO (martin) Handle chained messages from different users

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

        // html is raw content with additional html, raw content is just the text
        messagesElement.innerHTML = node.attrs.html;

        if (metaElement) {
          wrapper.appendChild(metaElement);
        }
        wrapper.appendChild(userElement);
        wrapper.appendChild(messagesElement);

        return wrapper;
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
    div_chat_transcript_wrap_open(state, token, tokens) {
      // TODO (martin) This needs to be getting the html_raw for the current
      // token only, otherwise it will get the first one every time
      const messagesHtml = tokens.find((t) => t.type === "html_raw")?.content;

      // So this content and the whole wrap_open happens for every single one of `[chat]`
      //
      // Only the first one will have multiQuote and chained
      //
      // Multiquote is > 1 message
      // Chained is > 1 message by different users
      //
      //
      //TODO: Maybe we do need a parent node to contain all these?
      state.openNode(state.schema.nodes.chat, {
        messageId: token.attrGet("data-message-id"),
        username: token.attrGet("data-username"),
        datetime: token.attrGet("data-datetime"),
        channelName: token.attrGet("data-channel-name"),
        channelId: token.attrGet("data-channel-id"),
        chained: token.attrGet("data-chained"),
        multiQuote: token.attrGet("data-multiquote"),
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
    div_chat_transcript_reactions: { ignore: true },
    div_chat_transcript_meta: { ignore: true },
    html_raw: { ignore: true, noCloseToken: true },
    span_open() {
      // TODO: not sure if i need to actually do anything here,
      // its just here to stop it erroring
      return true;
    },
    span_close() {
      return true;
    },
  },
};

export default extension;
