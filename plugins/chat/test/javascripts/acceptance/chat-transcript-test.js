import PrettyText, { buildOptions } from "pretty-text/pretty-text";
import { emojiUnescape } from "discourse/lib/text";
import I18n from "I18n";
import topicFixtures from "discourse/tests/fixtures/topic";
import { cloneJSON, deepMerge } from "discourse-common/lib/object";
import QUnit, { test } from "qunit";

import { click, fillIn, visit } from "@ember/test-helpers";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";

const rawOpts = {
  siteSettings: {
    enable_emoji: true,
    enable_emoji_shortcuts: true,
    enable_mentions: true,
    emoji_set: "twitter",
    external_emoji_url: "",
    highlighted_languages: "json|ruby|javascript",
    default_code_lang: "auto",
    enable_markdown_linkify: true,
    markdown_linkify_tlds: "com",
    chat_enabled: true,
  },
  getURL: (url) => url,
};

function cookMarkdown(input, opts) {
  const merged = deepMerge({}, rawOpts, opts);
  return new PrettyText(buildOptions(merged)).cook(input);
}

QUnit.assert.cookedChatTranscript = function (input, opts, expected, message) {
  const actual = cookMarkdown(input, opts);
  this.pushResult({
    result: actual === expected,
    actual,
    expected,
    message,
  });
};

function generateTranscriptHTML(messageContent, opts) {
  const channelDataAttr = opts.channel
    ? ` data-channel-name=\"${opts.channel}\"`
    : "";
  const channelIdDataAttr = opts.channelId
    ? ` data-channel-id=\"${opts.channelId}\"`
    : "";
  const reactDataAttr = opts.reactions
    ? ` data-reactions=\"${opts.reactionsAttr}\"`
    : "";

  let tabIndexHTML = opts.linkTabIndex ? ' tabindex="-1"' : "";

  let transcriptClasses = ["chat-transcript"];
  if (opts.chained) {
    transcriptClasses.push("chat-transcript-chained");
  }

  const transcript = [];
  transcript.push(
    `<div class=\"${transcriptClasses.join(" ")}\" data-message-id=\"${
      opts.messageId
    }\" data-username=\"${opts.username}\" data-datetime=\"${
      opts.datetime
    }\"${reactDataAttr}${channelDataAttr}${channelIdDataAttr}>`
  );

  if (opts.channel && opts.multiQuote) {
    let originallySent = I18n.t("chat.quote.original_channel", {
      channel: opts.channel,
      channelLink: `/chat/channel/${opts.channelId}/-`,
    });
    if (opts.linkTabIndex) {
      originallySent = originallySent.replace(">", tabIndexHTML + ">");
    }
    transcript.push(`<div class=\"chat-transcript-meta\">
${originallySent}</div>`);
  }

  const dateTimeText = opts.showDateTimeText
    ? moment
        .tz(opts.datetime, opts.timezone)
        .format(I18n.t("dates.long_no_year"))
    : "";

  const innerDatetimeEl =
    opts.noLink || !opts.channelId
      ? `<span title=\"${opts.datetime}\">${dateTimeText}</span>`
      : `<a href=\"/chat/channel/${opts.channelId}/-?messageId=${opts.messageId}\" title=\"${opts.datetime}\"${tabIndexHTML}>${dateTimeText}</a>`;
  transcript.push(`<div class=\"chat-transcript-user\">
<div class=\"chat-transcript-user-avatar\"></div>
<div class=\"chat-transcript-username\">
${opts.username}</div>
<div class=\"chat-transcript-datetime\">
${innerDatetimeEl}</div>`);

  if (opts.channel && !opts.multiQuote) {
    transcript.push(
      `<a class=\"chat-transcript-channel\" href="/chat/channel/${opts.channelId}/-"${tabIndexHTML}>
#${opts.channel}</a></div>`
    );
  } else {
    transcript.push("</div>");
  }

  let messageHtml = `<div class=\"chat-transcript-messages\">\n${messageContent}`;

  if (opts.reactions) {
    let reactionsHtml = [`<div class=\"chat-transcript-reactions\">\n`];
    opts.reactions.forEach((react) => {
      reactionsHtml.push(
        `<div class=\"chat-transcript-reaction\">\n${emojiUnescape(
          `:${react.emoji}:`,
          { lazy: true }
        ).replace(/'/g, '"')} ${react.usernames.length}</div>\n`
      );
    });
    reactionsHtml.push(`</div>\n`);
    messageHtml += reactionsHtml.join("");
  }
  transcript.push(`${messageHtml}</div>`);
  transcript.push("</div>");
  return transcript.join("\n");
}

// these are both set by the plugin with Site.markdown_additional_options which we can't really
// modify the response for here, source of truth are consts in ChatMessage::MARKDOWN_FEATURES
// and ChatMessage::MARKDOWN_IT_RULES
function buildAdditionalOptions() {
  return {
    chat: {
      limited_pretty_text_features: [
        "anchor",
        "bbcode-block",
        "bbcode-inline",
        "code",
        "category-hashtag",
        "censored",
        "discourse-local-dates",
        "emoji",
        "emojiShortcuts",
        "inlineEmoji",
        "html-img",
        "mentions",
        "onebox",
        "text-post-process",
        "upload-protocol",
        "watched-words",
        "table",
        "spoiler-alert",
      ],
      limited_pretty_text_markdown_rules: [
        "autolink",
        "list",
        "backticks",
        "newline",
        "code",
        "fence",
        "table",
        "linkify",
        "link",
        "strikethrough",
        "blockquote",
        "emphasis",
      ],
      hashtag_configurations: {
        "chat-composer": ["channel", "category", "tag"],
      },
    },
  };
}

acceptance("Discourse Chat | chat-transcript", function (needs) {
  let additionalOptions = buildAdditionalOptions();

  needs.user({
    admin: false,
    moderator: false,
    username: "eviltrout",
    id: 1,
    can_chat: false,
    has_chat_enabled: false,
    timezone: "Australia/Brisbane",
  });

  needs.settings({
    emoji_set: "twitter",
  });

  test("works with a minimal quote bbcode block", function (assert) {
    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nThis is a chat message.\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML("<p>This is a chat message.</p>", {
        messageId: "2321",
        username: "martin",
        datetime: "2022-01-25T05:40:39Z",
        timezone: "Australia/Brisbane",
      }),
      "renders the chat message with the required CSS classes and attributes"
    );
  });

  test("renders the channel name if provided with multiQuote", function (assert) {
    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z" channel="Cool Cats Club" channelId="1234" multiQuote="true"]\nThis is a chat message.\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML("<p>This is a chat message.</p>", {
        messageId: "2321",
        username: "martin",
        datetime: "2022-01-25T05:40:39Z",
        channel: "Cool Cats Club",
        channelId: "1234",
        multiQuote: true,
        timezone: "Australia/Brisbane",
      }),
      "renders the chat transcript with the channel name included above the user and datetime"
    );
  });

  test("renders the channel name if provided without multiQuote", function (assert) {
    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z" channel="Cool Cats Club" channelId="1234"]\nThis is a chat message.\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML("<p>This is a chat message.</p>", {
        messageId: "2321",
        username: "martin",
        datetime: "2022-01-25T05:40:39Z",
        channel: "Cool Cats Club",
        channelId: "1234",
        timezone: "Australia/Brisbane",
      }),
      "renders the chat transcript with the channel name included next to the datetime"
    );
  });

  test("renders with the chained attribute for more compact quotes", function (assert) {
    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z" channel="Cool Cats Club" channelId="1234" multiQuote="true" chained="true"]\nThis is a chat message.\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML("<p>This is a chat message.</p>", {
        messageId: "2321",
        username: "martin",
        datetime: "2022-01-25T05:40:39Z",
        channel: "Cool Cats Club",
        channelId: "1234",
        multiQuote: true,
        chained: true,
        timezone: "Australia/Brisbane",
      }),
      "renders with the chained attribute"
    );
  });

  test("renders with the noLink attribute to remove the links to the individual messages from the datetimes", function (assert) {
    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z" channel="Cool Cats Club" channelId="1234" multiQuote="true" noLink="true"]\nThis is a chat message.\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML("<p>This is a chat message.</p>", {
        messageId: "2321",
        username: "martin",
        datetime: "2022-01-25T05:40:39Z",
        channel: "Cool Cats Club",
        channelId: "1234",
        multiQuote: true,
        noLink: true,
        timezone: "Australia/Brisbane",
      }),
      "renders with the noLink attribute"
    );
  });

  test("renders with the reactions attribute", function (assert) {
    const reactionsAttr = "+1:martin;heart:martin,eviltrout";
    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z" channel="Cool Cats Club" channelId="1234" reactions="${reactionsAttr}"]\nThis is a chat message.\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML("<p>This is a chat message.</p>", {
        messageId: "2321",
        username: "martin",
        datetime: "2022-01-25T05:40:39Z",
        channel: "Cool Cats Club",
        channelId: "1234",
        timezone: "Australia/Brisbane",
        reactionsAttr,
        reactions: [
          { emoji: "+1", usernames: ["martin"] },
          { emoji: "heart", usernames: ["martin", "eviltrout"] },
        ],
      }),
      "renders with the reaction data attribute and HTML"
    );
  });

  test("renders with minimal markdown rules inside the quote bbcode block, same as server-side chat messages", function (assert) {
    assert.cookedChatTranscript(
      `[chat quote="johnsmith;450;2021-04-25T05:40:39Z"]
[quote="martin, post:3, topic:6215"]
another cool reply
[/quote]
[/chat]`,
      { additionalOptions },
      generateTranscriptHTML(
        `<p>[quote=&quot;martin, post:3, topic:6215&quot;]<br>
another cool reply<br>
[/quote]</p>`,
        {
          messageId: "450",
          username: "johnsmith",
          datetime: "2021-04-25T05:40:39Z",
          timezone: "Australia/Brisbane",
        }
      ),
      "does not render the markdown feature that has been excluded"
    );

    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nThis ~~does work~~ with removed _rules_.\n\n* list item 1\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML(
        `<p>This <s>does work</s> with removed <em>rules</em>.</p>
<ul>
<li>list item 1</li>
</ul>`,
        {
          messageId: "2321",
          username: "martin",
          datetime: "2022-01-25T05:40:39Z",
          timezone: "Australia/Brisbane",
        }
      ),
      "renders correctly when the rule has not been excluded"
    );

    additionalOptions.chat.limited_pretty_text_markdown_rules = [
      "autolink",
      // "list",
      "backticks",
      "newline",
      "code",
      "fence",
      "table",
      "linkify",
      "link",
      // "strikethrough",
      "blockquote",
      // "emphasis",
    ];

    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nThis ~~does work~~ with removed _rules_.\n\n* list item 1\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML(
        `<p>This ~~does work~~ with removed _rules_.</p>
<p>* list item 1</p>`,
        {
          messageId: "2321",
          username: "martin",
          datetime: "2022-01-25T05:40:39Z",
          timezone: "Australia/Brisbane",
        }
      ),
      "renders correctly with some obvious rules excluded (list/strikethrough/emphasis)"
    );

    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nhere is a message :P with category hashtag #test\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML(
        `<p>here is a message <img src=\"/images/emoji/twitter/stuck_out_tongue.png?v=12\" title=\":stuck_out_tongue:\" class=\"emoji\" alt=\":stuck_out_tongue:\" loading=\"lazy\" width=\"20\" height=\"20\"> with category hashtag <span class=\"hashtag\">#test</span></p>`,
        {
          messageId: "2321",
          username: "martin",
          datetime: "2022-01-25T05:40:39Z",
          timezone: "Australia/Brisbane",
        }
      ),
      "renders correctly when the feature has not been excluded"
    );

    additionalOptions.chat.limited_pretty_text_features = [
      "anchor",
      "bbcode-block",
      "bbcode-inline",
      "code",
      // "category-hashtag",
      "censored",
      "discourse-local-dates",
      "emoji",
      // "emojiShortcuts",
      "inlineEmoji",
      "html-img",
      "mentions",
      "onebox",
      "text-post-process",
      "upload-protocolrouter.location.setURL",
      "watched-words",
      "table",
      "spoiler-alert",
    ];

    assert.cookedChatTranscript(
      `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nhere is a message :P with category hashtag #test\n[/chat]`,
      { additionalOptions },
      generateTranscriptHTML(
        `<p>here is a message :P with category hashtag #test</p>`,
        {
          messageId: "2321",
          username: "martin",
          datetime: "2022-01-25T05:40:39Z",
          timezone: "Australia/Brisbane",
        }
      ),
      "renders correctly with some obvious features excluded (category-hashtag, emojiShortcuts)"
    );

    assert.cookedChatTranscript(
      `This ~~does work~~ with removed _rules_.

* list item 1

here is a message :P with category hashtag #test

[chat quote="martin;2321;2022-01-25T05:40:39Z"]
This ~~does work~~ with removed _rules_.

* list item 1

here is a message :P with category hashtag #test
[/chat]`,
      { additionalOptions },
      `<p>This <s>does work</s> with removed <em>rules</em>.</p>
<ul>
<li>list item 1</li>
</ul>
<p>here is a message <img src=\"/images/emoji/twitter/stuck_out_tongue.png?v=12\" title=\":stuck_out_tongue:\" class=\"emoji\" alt=\":stuck_out_tongue:\" loading=\"lazy\" width=\"20\" height=\"20\"> with category hashtag <span class=\"hashtag\">#test</span></p>\n` +
        generateTranscriptHTML(
          `<p>This ~~does work~~ with removed _rules_.</p>
<p>* list item 1</p>
<p>here is a message :P with category hashtag #test</p>`,
          {
            messageId: "2321",
            username: "martin",
            datetime: "2022-01-25T05:40:39Z",
            timezone: "Australia/Brisbane",
          }
        ),
      "the rule changes do not apply outside the BBCode [chat] block"
    );
  });
});

acceptance(
  "Discourse Chat | chat-transcript date decoration",
  function (needs) {
    let additionalOptions = buildAdditionalOptions();

    needs.user({
      admin: false,
      moderator: false,
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
      timezone: "Australia/Brisbane",
    });
    needs.settings({
      chat_enabled: true,
    });

    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () =>
        helper.response({
          public_channels: [],
          direct_message_channels: [],
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        })
      );

      const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
      const firstPost = topicResponse.post_stream.posts[0];
      const postCooked = cookMarkdown(
        `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nThis is a chat message.\n[/chat]`,
        { additionalOptions }
      );
      firstPost.cooked += postCooked;

      server.get("/t/280.json", () => helper.response(topicResponse));
    });

    test("chat transcript datetimes are formatted into the link with decorateCookedElement", async function (assert) {
      await visit("/t/-/280");

      assert.strictEqual(
        query(".chat-transcript-datetime span").innerText.trim(),
        moment
          .tz("2022-01-25T05:40:39Z", "Australia/Brisbane")
          .format(I18n.t("dates.long_no_year")),
        "it decorates the chat transcript datetime link with a formatted date"
      );
    });
  }
);

acceptance(
  "Discourse Chat - chat-transcript - Composer Oneboxes ",
  function (needs) {
    let additionalOptions = buildAdditionalOptions();
    needs.user({
      admin: false,
      moderator: false,
      username: "eviltrout",
      id: 1,
      can_chat: true,
      has_chat_enabled: true,
      timezone: "Australia/Brisbane",
    });
    needs.settings({
      chat_enabled: true,
      enable_markdown_linkify: true,
      max_oneboxes_per_post: 2,
    });
    needs.pretender((server, helper) => {
      server.get("/chat/chat_channels.json", () =>
        helper.response({
          public_channels: [],
          direct_message_channels: [],
          message_bus_last_ids: {
            channel_metadata: 0,
            channel_edits: 0,
            channel_status: 0,
            new_channel: 0,
            user_tracking_state: 0,
          },
        })
      );

      const topicResponse = cloneJSON(topicFixtures["/t/280/1.json"]);
      const firstPost = topicResponse.post_stream.posts[0];
      const postCooked = cookMarkdown(
        `[chat quote="martin;2321;2022-01-25T05:40:39Z"]\nThis is a chat message.\n[/chat]`,
        { additionalOptions }
      );
      firstPost.cooked += postCooked;

      server.get("/t/280.json", () => helper.response(topicResponse));
    });

    test("Preview should not error for oneboxes within [chat] bbcode", async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click("#topic-footer-buttons .btn.create");

      await fillIn(
        ".d-editor-input",
        `
[chat quote="martin;2321;2022-01-25T05:40:39Z" channel="Cool Cats Club" channelId="1234" multiQuote="true"]
http://www.example.com/has-title.html
[/chat]`
      );

      const rendered = generateTranscriptHTML(
        '<p><aside class="onebox"><article class="onebox-body"><h3><a href="http://www.example.com/article.html" tabindex="-1">An interesting article</a></h3></article></aside></p>',
        {
          messageId: "2321",
          username: "martin",
          datetime: "2022-01-25T05:40:39Z",
          channel: "Cool Cats Club",
          channelId: "1234",
          multiQuote: true,
          linkTabIndex: true,
          showDateTimeText: true,
          timezone: "Australia/Brisbane",
        }
      );

      assert.strictEqual(
        query(".d-editor-preview").innerHTML.trim(),
        rendered.trim(),
        "it renders correctly with the onebox inside the [chat] bbcode"
      );

      const textarea = query("#reply-control .d-editor-input");
      await fillIn(".d-editor-input", textarea.value + "\nA");
      assert.ok(
        query(".d-editor-preview").innerHTML.trim().includes("\n<p>A</p>"),
        "it does not error with a opts.discourse.hoisted error in the markdown pipeline when typing more text"
      );
    });
  }
);
