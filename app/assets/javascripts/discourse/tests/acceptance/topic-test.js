import {
  acceptance,
  count,
  exists,
  query,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import {
  click,
  fillIn,
  settled,
  triggerKeyEvent,
  visit,
} from "@ember/test-helpers";
import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";

async function selectText(selector) {
  const range = document.createRange();
  const node = document.querySelector(selector);
  range.selectNodeContents(node);

  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
  await settled();
}

acceptance("Topic", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.put("/posts/398/wiki", () => {
      return helper.response({});
    });
  });

  test("Reply as new topic", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("button.share:nth-of-type(1)");
    await click(".reply-as-new-topic a");

    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    assert.equal(
      queryAll(".d-editor-input").val().trim(),
      `Continuing the discussion from [Internationalization / localization](${window.location.origin}/t/internationalization-localization/280):`,
      "it fills composer with the ring string"
    );
    assert.equal(
      selectKit(".category-chooser").header().value(),
      "2",
      "it fills category selector with the right category"
    );
  });

  test("Reply as new message", async function (assert) {
    await visit("/t/pm-for-testing/12");
    await click("button.share:nth-of-type(1)");
    await click(".reply-as-new-topic a");

    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    assert.equal(
      queryAll(".d-editor-input").val().trim(),
      `Continuing the discussion from [PM for testing](${window.location.origin}/t/pm-for-testing/12):`,
      "it fills composer with the ring string"
    );

    const targets = queryAll(
      "#private-message-users .selected-name",
      ".composer-fields"
    );

    assert.equal(
      $(targets[0]).text().trim(),
      "someguy",
      "it fills up the composer with the right user to start the PM to"
    );

    assert.equal(
      $(targets[1]).text().trim(),
      "test",
      "it fills up the composer with the right user to start the PM to"
    );

    assert.equal(
      $(targets[2]).text().trim(),
      "Group",
      "it fills up the composer with the right group to start the PM to"
    );
  });

  test("Share Modal", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:first-child button.share");

    assert.ok(exists("#share-link"), "it shows the share modal");
  });

  test("Showing and hiding the edit controls", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-title .d-icon-pencil-alt");

    assert.ok(exists("#edit-title"), "it shows the editing controls");
    assert.ok(
      !exists(".title-wrapper .remove-featured-link"),
      "link to remove featured link is not shown"
    );

    await fillIn("#edit-title", "this is the new title");
    await click("#topic-title .cancel-edit");
    assert.ok(!exists("#edit-title"), "it hides the editing controls");
  });

  test("Updating the topic title and category", async function (assert) {
    const categoryChooser = selectKit(".title-wrapper .category-chooser");

    await visit("/t/internationalization-localization/280");

    await click("#topic-title .d-icon-pencil-alt");
    await fillIn("#edit-title", "this is the new title");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(4);
    await click("#topic-title .submit-edit");

    assert.equal(
      queryAll("#topic-title .badge-category").text(),
      "faq",
      "it displays the new category"
    );
    assert.equal(
      queryAll(".fancy-title").text().trim(),
      "this is the new title",
      "it displays the new title"
    );
  });

  test("Marking a topic as wiki", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.ok(!exists("a.wiki"), "it does not show the wiki icon");

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.show-post-admin-menu");
    await click(".btn.wiki");

    assert.equal(count("button.wiki"), 1, "it shows the wiki icon");
  });

  test("Visit topic routes", async function (assert) {
    await visit("/t/12");

    assert.equal(
      queryAll(".fancy-title").text().trim(),
      "PM for testing",
      "it routes to the right topic"
    );

    await visit("/t/280/20");

    assert.equal(
      queryAll(".fancy-title").text().trim(),
      "Internationalization / localization",
      "it routes to the right topic"
    );
  });

  test("Updating the topic title with emojis", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-title .d-icon-pencil-alt");

    await fillIn("#edit-title", "emojis title :bike: :blonde_woman:t6:");

    await click("#topic-title .submit-edit");

    assert.ok(
      queryAll(".fancy-title").html().trim().indexOf("bike.png") !== -1,
      "it displays the new title with emojis"
    );
  });

  test("Updating the topic title with unicode emojis", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-title .d-icon-pencil-alt");

    await fillIn("#edit-title", "emojis title 👨‍🌾🙏");

    await click("#topic-title .submit-edit");

    assert.ok(
      queryAll(".fancy-title").html().trim().indexOf("man_farmer.png") !== -1,
      "it displays the new title with emojis"
    );
  });

  test("Updating the topic title with unicode emojis without whitespaces", async function (assert) {
    this.siteSettings.enable_inline_emoji_translation = true;
    await visit("/t/internationalization-localization/280");
    await click("#topic-title .d-icon-pencil-alt");

    await fillIn("#edit-title", "Test🙂Title");

    await click("#topic-title .submit-edit");

    assert.ok(
      queryAll(".fancy-title")
        .html()
        .trim()
        .indexOf("slightly_smiling_face.png") !== -1,
      "it displays the new title with emojis"
    );
  });

  test("Suggested topics", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.equal(
      queryAll("#suggested-topics .suggested-topics-title").text().trim(),
      I18n.t("suggested_topics.title")
    );
  });

  test("Deleting a topic", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".widget-button.delete");
    await click(".toggle-admin-menu");
    assert.ok(exists(".topic-admin-recover"), "it shows the recover button");
  });

  test("Deleting a popular topic displays confirmation modal", async function (assert) {
    this.siteSettings.min_topic_views_for_delete_confirm = 10;
    await visit("/t/internationalization-localization/280");
    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".widget-button.delete");
    assert.ok(
      visible(".delete-topic-confirm-modal"),
      "it shows the delete confirmation modal"
    );

    await click(".delete-topic-confirm-modal .btn-primary");
    assert.ok(
      !visible(".delete-topic-confirm-modal"),
      "it hides the delete confirmation modal"
    );
    await click(".widget-button.delete");
    await click(".delete-topic-confirm-modal .btn-danger");
    await click(".toggle-admin-menu");
    assert.ok(exists(".topic-admin-recover"), "it shows the recover button");
  });

  test("Group category moderator posts", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");

    assert.ok(exists(".category-moderator"), "it has a class applied");
    assert.ok(exists(".d-icon-shield-alt"), "it shows an icon");
  });
});

acceptance("Topic featured links", function (needs) {
  needs.user();
  needs.settings({
    topic_featured_link_enabled: true,
    max_topic_title_length: 80,
    exclude_rel_nofollow_domains: "example.com",
  });

  test("remove nofollow attribute", async function (assert) {
    await visit("/t/-/299/1");

    const link = queryAll(".title-wrapper .topic-featured-link");
    assert.equal(link.text(), " example.com");
    assert.equal(link.attr("rel"), "ugc");
  });

  test("remove featured link", async function (assert) {
    await visit("/t/-/299/1");
    assert.ok(
      exists(".title-wrapper .topic-featured-link"),
      "link is shown with topic title"
    );

    await click(".title-wrapper .edit-topic");
    assert.ok(
      exists(".title-wrapper .remove-featured-link"),
      "link to remove featured link"
    );

    // TODO: decide if we want to test this, test is flaky so it
    // was commented out.
    // If not fixed by May 2021, delete this code block
    //
    //await click(".title-wrapper .remove-featured-link");
    //await click(".title-wrapper .submit-edit");
    //assert.ok(!exists(".title-wrapper .topic-featured-link"), "link is gone");
  });

  test("Converting to a public topic", async function (assert) {
    await visit("/t/test-pm/34");
    assert.ok(exists(".private_message"));
    await click(".toggle-admin-menu");
    await click(".topic-admin-convert button");

    let categoryChooser = selectKit(
      ".convert-to-public-topic .category-chooser"
    );
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(21);

    await click(".convert-to-public-topic .btn-primary");
    assert.ok(!exists(".private_message"));
  });

  test("Unpinning unlisted topic", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".toggle-admin-menu");
    await click(".topic-admin-pin .btn");
    await click(".make-banner");

    await click(".toggle-admin-menu");
    await click(".topic-admin-visible .btn");

    await click(".toggle-admin-menu");
    assert.ok(
      exists(".topic-admin-pin"),
      "it should show the multi select menu"
    );
  });

  test("selecting posts", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");

    assert.ok(
      exists(".selected-posts:not(.hidden)"),
      "it should show the multi select menu"
    );

    assert.ok(
      exists(".select-all"),
      "it should allow users to select all the posts"
    );
  });

  test("select below", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".toggle-admin-menu");
    await click(".topic-admin-multi-select .btn");
    await click("#post_3 .select-below");

    assert.ok(
      queryAll(".selected-posts")
        .html()
        .includes(I18n.t("topic.multi_select.description", { count: 18 })),
      "it should select the right number of posts"
    );

    await click("#post_2 .select-below");

    assert.ok(
      queryAll(".selected-posts")
        .html()
        .includes(I18n.t("topic.multi_select.description", { count: 19 })),
      "it should select the right number of posts"
    );
  });

  test("View Hidden Replies", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".gap");

    assert.ok(!exists(".gap"), "it hides gap");
  });

  test("Quoting a quote keeps the original poster name", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_5 blockquote");
    await click(".quote-button .insert-quote");

    assert.ok(
      queryAll(".d-editor-input")
        .val()
        .indexOf('quote="codinghorror said, post:3, topic:280"') !== -1
    );
  });

  test("Quoting a quote of a different topic keeps the original topic title", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_9 blockquote");
    await click(".quote-button .insert-quote");

    assert.ok(
      queryAll(".d-editor-input")
        .val()
        .indexOf(
          'quote="A new topic with a link to another topic, post:3, topic:62"'
        ) !== -1
    );
  });

  test("Quoting a quote with the Reply button keeps the original poster name", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_5 blockquote");
    await click(".reply");

    assert.ok(
      queryAll(".d-editor-input")
        .val()
        .indexOf('quote="codinghorror said, post:3, topic:280"') !== -1
    );
  });

  test("Quoting a quote with replyAsNewTopic keeps the original poster name", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_5 blockquote");
    await triggerKeyEvent(document, "keypress", "j".charCodeAt(0));
    await triggerKeyEvent(document, "keypress", "t".charCodeAt(0));

    assert.ok(
      queryAll(".d-editor-input")
        .val()
        .indexOf('quote="codinghorror said, post:3, topic:280"') !== -1
    );
  });

  test("Quoting by selecting text can mark the quote as full", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await selectText("#post_5 .cooked");
    await click(".quote-button .insert-quote");

    assert.ok(
      queryAll(".d-editor-input")
        .val()
        .indexOf('quote="pekka, post:5, topic:280, full:true"') !== -1
    );
  });
});

acceptance("Topic featured links", function (needs) {
  needs.user();
  needs.settings({
    topic_featured_link_enabled: true,
    max_topic_title_length: 80,
  });

  test("remove featured link", async function (assert) {
    await visit("/t/-/299/1");
    assert.ok(
      exists(".title-wrapper .topic-featured-link"),
      "link is shown with topic title"
    );

    await click(".title-wrapper .edit-topic");
    assert.ok(
      exists(".title-wrapper .remove-featured-link"),
      "link to remove featured link"
    );
  });
});

acceptance("Topic with title decorated", function (needs) {
  needs.user();
  needs.hooks.beforeEach(() => {
    withPluginApi("0.8.40", (api) => {
      api.decorateTopicTitle((topic, node, topicTitleType) => {
        node.innerText = `${node.innerText}-${topic.id}-${topicTitleType}`;
      });
    });
  });

  test("Decorate topic title", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert.ok(
      query(".fancy-title").innerText.endsWith("-280-topic-title"),
      "it decorates topic title"
    );

    assert.ok(
      query(".raw-topic-link:nth-child(1)").innerText.endsWith(
        "-27331-topic-list-item-title"
      ),
      "it decorates topic list item title"
    );
  });
});

acceptance("Topic pinning/unpinning as an admin", function (needs) {
  needs.user({ admin: true });

  test("Admin pinning topic", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");

    await click(".toggle-admin-menu");
    await click(".topic-admin-pin .btn");

    assert.ok(
      exists(".feature-topic .btn-primary"),
      "it should show the 'Pin Topic' button"
    );

    assert.ok(
      exists(".make-banner"),
      "it should show the 'Banner Topic' button"
    );
  });
});

acceptance("Topic pinning/unpinning as a staff member", function (needs) {
  needs.user({ moderator: true, admin: false, trust_level: 2 });

  test("Staff pinning topic", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");

    await click(".toggle-admin-menu");
    await click(".topic-admin-pin .btn");

    assert.ok(
      exists(".feature-topic .btn-primary"),
      "it should show the 'Pin Topic' button"
    );

    assert.ok(
      exists(".make-banner"),
      "it should show the 'Banner Topic' button"
    );
  });
});

acceptance("Topic pinning/unpinning as a group moderator", function (needs) {
  needs.user({ moderator: false, admin: false, trust_level: 1 });

  test("Group category moderator pinning topic", async function (assert) {
    await visit("/t/topic-for-group-moderators/2480");

    await click(".toggle-admin-menu");
    await click(".topic-admin-pin .btn");

    assert.ok(
      exists(".feature-topic .btn-primary"),
      "it should show the 'Pin Topic' button"
    );

    assert.ok(
      !exists(".make-banner"),
      "it should not show the 'Banner Topic' button"
    );
  });
});

acceptance("Topic last visit line", function (needs) {
  needs.user({ moderator: false, admin: false, trust_level: 1 });

  test("visit topic", async function (assert) {
    await visit("/t/-/280");

    assert.ok(
      exists(".topic-post-visited-line.post-10"),
      "shows the last visited line on the right post"
    );

    await visit("/t/-/9");

    assert.ok(
      !exists(".topic-post-visited-line"),
      "does not show last visited line if post is the last post"
    );
  });
});
