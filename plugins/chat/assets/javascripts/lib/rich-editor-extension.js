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
      },
      content: "block+",
      group: "block",
      isolating: true,
      selectable: true,
      parseDOM: [{ tag: "div.chat-transcript" }],
      toDOM(node) {
        const dom = document.createElement("div");
        dom.classList.add("chat-transcript");
        const user = document.createElement("div");
        user.classList.add("chat-transcript-user");
        user.innerHTML = `<span class="chat-transcript-username">${node.attrs.username}</span>`;
        const messages = document.createElement("div");
        messages.classList.add("chat-transcript-messages");
        messages.innerHTML = node.attrs.html;

        dom.appendChild(user);
        dom.appendChild(messages);

        return dom;
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

      // todo: handle chained and multiQuote

      state.write(`[chat ${bbCodeAttrs.join(" ")}]`);
      state.renderContent(node);
      state.write("[/chat]");
    },
  },
  parse: {
    chat: { ignore: true, noCloseToken: true },
    div_chat_transcript_wrap_open(state, token, tokens) {
      const messagesHtml = tokens.find((t) => t.type === "html_raw")?.content;
      state.openNode(state.schema.nodes.chat, {
        messageId: token.attrGet("data-message-id"),
        username: token.attrGet("data-username"),
        datetime: token.attrGet("data-datetime"),
        channelName: token.attrGet("data-channel-name"),
        channelId: token.attrGet("data-channel-id"),
        html: messagesHtml,
      });
      return true;
    },
    div_chat_transcript_wrap_close(state) {
      state.closeNode();
      return true;
    },
    div_chat_transcript_user: {
      ignore: true,
    },
    div_chat_transcript_user_avatar: {
      ignore: true,
    },
    div_chat_transcript_username: {
      ignore: true,
    },
    div_chat_transcript_datetime: {
      ignore: true,
    },
    div_chat_transcript_messages: {
      ignore: true,
    },
    div_chat_transcript_reaction: { ignore: true },
    div_chat_transcript_reactions: { ignore: true },
    div_chat_transcript_meta: { ignore: true },
    html_raw: { ignore: true, noCloseToken: true },
  },
};

export default extension;
