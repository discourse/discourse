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
      },
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

        // html is raw content with additional html, raw content is just the text
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
