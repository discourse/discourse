// need to account for both one message from single user,
// multiple messages from single user,
// and multiple messages from multiple users
/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    chat_transcript: {
      content:
        "block* chat_transcript_meta chat_transcript_user chat_transcript_messages",
      draggable: true,
      selectable: true,
      defining: true,
      parseDOM: [{ tag: "div.chat-transcript" }],
      toDOM() {
        console.log("chat_transcript");
        return ["div", { class: "chat-transcript" }, 0];
      },
    },
    chat_transcript_user: {
      content: "chat_transcript_user_details inline",
      draggable: false,
      selectable: false,
      parseDOM: [{ tag: "div.chat-transcript-user" }],
      toDOM() {
        console.log("chat_transcript_user");
        return ["div", { class: "chat-transcript-user" }, 0];
      },
    },
    chat_transcript_datetime: {
      content: "inline*",
      group: "chat_transcript_user_details",
      draggable: false,
      selectable: false,
      inline: true,
      parseDOM: [{ tag: "div.chat-transcript-datetime" }],
      toDOM() {
        console.log("chat_transcript_datetime");
        return ["div", { class: "chat-transcript-datetime" }, 0];
      },
    },
    chat_transcript_messages: {
      content: "inline*",
      group: "chat_transcript",
      draggable: false,
      selectable: false,
      parseDOM: [
        {
          tag: "div.chat-transcript-messages",
          getAttrs(dom) {
            return { html: dom.innerHTML };
          },
        },
      ],
      toDOM() {
        console.log("chat_transcript_messages");
        return ["div", { class: "chat-transcript-messages" }, 0];
      },
    },
    chat_transcript_user_avatar: {
      content: "inline*",
      group: "chat_transcript_user_details",
      draggable: false,
      selectable: false,
      inline: true,
      parseDOM: [{ tag: "div.chat-transcript-user-avatar" }],
      toDOM() {
        console.log("chat_transcript_user_avatar");
        return ["div", { class: "chat-transcript-user-avatar" }, 0];
      },
    },
    chat_transcript_username: {
      content: "inline*",
      group: "chat_transcript_user_details",
      draggable: false,
      selectable: false,
      inline: true,
      parseDOM: [{ tag: "div.chat-transcript-username" }],
      toDOM() {
        console.log("chat_transcript_username");
        return ["div", { class: "chat-transcript-username" }, 0];
      },
    },
    chat_transcript_messages_html: {
      content: "block*",
      group: "block",
      draggable: false,
      selectable: false,
      toDOM() {
        console.log("chat_transcript_messages_html");
        return ["div", {}, 0];
      },
    },
    chat_transcript_meta: {
      content: "inline*",
      group: "chat_transcript",
      draggable: false,
      selectable: false,
      parseDOM: [{ tag: "div.chat-transcript-meta" }],
      toDOM() {
        console.log("chat_transcript_meta");
        return ["div", { class: "chat-transcript-meta" }, 0];
      },
    },
  },
  serializeNode: {
    chat_transcript(state, node) {
      console.log(state, node);
    },
  },
  parse: {
    div_chat_transcript_wrap: { block: "chat_transcript" },
    div_chat_transcript_user: {
      block: "chat_transcript_user",
    },
    div_chat_transcript_user_avatar: {
      block: "chat_transcript_user_avatar",
    },
    div_chat_transcript_username: {
      block: "chat_transcript_username",
    },
    div_chat_transcript_datetime: {
      block: "chat_transcript_datetime",
    },
    div_chat_transcript_messages: {
      block: "chat_transcript_messages",
    },
    // div_chat_transcript_reaction(state, token) {
    //   console.log(state, token);
    // },
    // div_chat_transcript_reactions(state, token) {
    //   console.log(state, token);
    // },
    div_chat_transcript_meta: {
      block: "chat_transcript_meta",
    },
    html_raw: { block: "chat_transcript_messages_html" },
  },
  // serializeNode: {
  //   chat(state, node) {
  //     console.log(state, node);
  //   },
  // },
};

export default extension;
