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
      selectable: true,
      isolating: true,
      parseDOM: [{ tag: "div.chat-transcript" }],
      toDOM(node) {
        const dom = document.createElement("div");
        dom.classList.add("chat-transcript");
        dom.innerHTML = node.attrs.html;
        return dom;
      },
    },
  },
  serializeNode: {
    chat(state, node) {
      state.write("[chat]");
      state.renderContent(node);
      state.write("[/chat]");
    },
  },
  parse: {
    chat: { ignore: true },
    div_chat_transcript_wrap_open(state, token, tokens) {
      const messagesHtml = tokens.find(
        (t) => t.type === "html_raw_open"
      )?.content;
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
    html_raw: { ignore: true },
  },
};

export default extension;
