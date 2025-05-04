import { getOwner } from "@ember/owner";
import { module, test } from "qunit";
import {
  registerRichEditorExtension,
  resetRichEditorExtensions,
} from "discourse/lib/composer/rich-editor-extensions";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { setupRichEditor } from "discourse/tests/helpers/rich-editor-helper";
import richEditorExtension from "discourse/plugins/chat/lib/rich-editor-extension";

module(
  "Integration | Component | prosemirror-editor - chat transcript extension",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.rich_editor = true;
      this.siteSettings.chat_enabled = true;

      // This is necessary for the chat transcripts to work in JS, because this
      // is necessary for the markdown-it rule to run, this tells chat what
      // pretty text features and markdown rules are allowed in chat transcripts.
      const site = getOwner(this).lookup("service:site");
      site.set(
        "markdown_additional_options",
        JSON.parse(
          '{"chat":{"limited_pretty_text_features":["anchor","bbcode-block","bbcode-inline","code","category-hashtag","censored","chat-transcript","discourse-local-dates","emoji","emojiShortcuts","inlineEmoji","html-img","hashtag-autocomplete","mentions","unicodeUsernames","onebox","quotes","spoiler-alert","table","text-post-process","upload-protocol","watched-words","chat-html-inline"],"limited_pretty_text_markdown_rules":["autolink","list","backticks","newline","code","fence","image","table","linkify","link","strikethrough","blockquote","emphasis","replacements","escape"],"hashtag_configurations":{"topic-composer":["category","tag","channel"],"chat-composer":["channel","category","tag"]}}}'
        )
      );

      resetRichEditorExtensions().then(() => {
        registerRichEditorExtension(richEditorExtension);
      });
    });

    test("single message from single user transcript", async function (assert) {
      const singleMessageSingleUserMarkdown = `[chat quote="hunter;29856;2025-03-20T07:13:04Z" channel="design gems :tada:" channelId="95"]
haha **ok** _cool_
[/chat]
`;
      const [{ value }] = await setupRichEditor(
        assert,
        singleMessageSingleUserMarkdown
      );
      const rootElement = document.querySelector(
        ".ProseMirror .chat-transcript"
      );
      assert
        .dom(".chat-transcript-messages", rootElement)
        .hasHtml("<p>haha <strong>ok</strong> <em>cool</em></p>");
      assert
        .dom(".chat-transcript-user .chat-transcript-username", rootElement)
        .hasText("hunter");
      assert
        .dom(".chat-transcript-user .chat-transcript-datetime", rootElement)
        .exists();
      assert
        .dom(".chat-transcript-channel", rootElement)
        .hasText("#design gems");
      assert
        .dom(".chat-transcript-channel", rootElement)
        .hasAttribute("href", "/chat/c/-/95");
      assert.dom(".chat-transcript-channel img[title='tada']").exists();

      assert.strictEqual(value, singleMessageSingleUserMarkdown);
    });

    test("multiple messages from multiple different users", async function (assert) {
      const multiMessagesMultiUserMarkdown = `[chat quote="martin;29853;2025-03-20T07:12:55Z" channel="design gems :tada:" channelId="95" multiQuote="true" chained="true"]
test
[/chat]
[chat quote="hunter;29856;2025-03-20T07:13:04Z" chained="true"]
haha **ok** _cool_
[/chat]
`;
      const [{ value }] = await setupRichEditor(
        assert,
        multiMessagesMultiUserMarkdown
      );

      assert.dom(".chat-transcript").exists({ count: 2 });
      assert.dom(".chat-transcript-messages").exists({ count: 2 });
      assert.dom(".chat-transcript-user").exists({ count: 2 });
      assert
        .dom(".chat-transcript:nth-of-type(1)")
        .hasClass("chat-transcript-chained");
      assert
        .dom(".chat-transcript-meta")
        .hasText("Originally sent in design gems");
      assert.dom(".chat-transcript-meta img[title='tada']").exists();

      let rootElement = document.querySelector(
        ".ProseMirror .chat-transcript:nth-of-type(1)"
      );
      assert
        .dom(".chat-transcript-messages", rootElement)
        .hasHtml("<p>test</p>");
      assert
        .dom(".chat-transcript-user .chat-transcript-username", rootElement)
        .hasText("martin");

      rootElement = document.querySelector(
        ".ProseMirror .chat-transcript:nth-of-type(2)"
      );
      assert
        .dom(".chat-transcript-messages", rootElement)
        .hasHtml("<p>haha <strong>ok</strong> <em>cool</em></p>");
      assert
        .dom(".chat-transcript-user .chat-transcript-username", rootElement)
        .hasText("hunter");

      assert.strictEqual(value, multiMessagesMultiUserMarkdown);
    });

    test("messages in a thread", async function (assert) {
      const threadMessagesMarkdown = `[chat quote="martin;29854;2025-03-20T07:12:57Z" channel="design gems :tada:" channelId="95" multiQuote="true" threadId="124" threadTitle="Some cool thread title"]
thread op message

[chat quote="martin;29857;2025-03-24T07:08:01Z"]
thread other message
[/chat]

[/chat]
`;
      const [{ value }] = await setupRichEditor(assert, threadMessagesMarkdown);
      assert
        .dom(".chat-transcript-meta")
        .hasText("Originally sent in design gems");
      assert.dom(".chat-transcript-meta img[title='tada']").exists();
      assert
        .dom(".chat-transcript details summary .chat-transcript-thread")
        .exists();

      let rootElement = document.querySelector(
        ".ProseMirror .chat-transcript details summary .chat-transcript-thread"
      );
      assert
        .dom(
          ".chat-transcript-thread-header svg.d-icon-discourse-threads",
          rootElement
        )
        .exists();
      assert
        .dom(
          ".chat-transcript-thread-header .chat-transcript-thread-header__title",
          rootElement
        )
        .hasText("Some cool thread title");

      assert
        .dom(".chat-transcript-messages", rootElement)
        .hasHtml(
          "<p>thread op message</p>",
          "the thread op message is inside the summary element"
        );
      assert
        .dom(".chat-transcript-user .chat-transcript-username", rootElement)
        .hasText("martin");

      rootElement = document.querySelector(
        ".ProseMirror .chat-transcript details .chat-transcript"
      );
      assert
        .dom(".chat-transcript-messages", rootElement)
        .hasHtml(
          "<p>thread other message</p>",
          "the other thread messages are inside the details element"
        );
      assert
        .dom(".chat-transcript-user .chat-transcript-username", rootElement)
        .hasText("martin");

      assert.strictEqual(value, threadMessagesMarkdown);
    });
  }
);
