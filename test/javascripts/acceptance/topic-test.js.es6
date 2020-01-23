import selectKit from "helpers/select-kit-helper";
import { acceptance } from "helpers/qunit-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji/version";

acceptance("Topic", {
  loggedIn: true,
  pretend(server, helper) {
    server.put("/posts/398/wiki", () => {
      return helper.response({});
    });
  }
});

QUnit.test("Reply as new topic", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("button.share:eq(0)");
  await click(".reply-as-new-topic a");

  assert.ok(exists(".d-editor-input"), "the composer input is visible");

  assert.equal(
    find(".d-editor-input")
      .val()
      .trim(),
    `Continuing the discussion from [Internationalization / localization](${window.location.origin}/t/internationalization-localization/280):`,
    "it fills composer with the ring string"
  );
  assert.equal(
    selectKit(".category-chooser")
      .header()
      .value(),
    "2",
    "it fills category selector with the right category"
  );
});

QUnit.test("Reply as new message", async assert => {
  await visit("/t/pm-for-testing/12");
  await click("button.share:eq(0)");
  await click(".reply-as-new-topic a");

  assert.ok(exists(".d-editor-input"), "the composer input is visible");

  assert.equal(
    find(".d-editor-input")
      .val()
      .trim(),
    `Continuing the discussion from [PM for testing](${window.location.origin}/t/pm-for-testing/12):`,
    "it fills composer with the ring string"
  );

  const targets = find(".item span", ".composer-fields");

  assert.equal(
    $(targets[0]).text(),
    "someguy",
    "it fills up the composer with the right user to start the PM to"
  );

  assert.equal(
    $(targets[1]).text(),
    "test",
    "it fills up the composer with the right user to start the PM to"
  );

  assert.equal(
    $(targets[2]).text(),
    "Group",
    "it fills up the composer with the right group to start the PM to"
  );
});

QUnit.test("Share Modal", async assert => {
  await visit("/t/internationalization-localization/280");
  await click(".topic-post:first-child button.share");

  assert.ok(exists("#share-link"), "it shows the share modal");
});

QUnit.test("Showing and hiding the edit controls", async assert => {
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

QUnit.test("Updating the topic title and category", async assert => {
  const categoryChooser = selectKit(".title-wrapper .category-chooser");

  await visit("/t/internationalization-localization/280");

  await click("#topic-title .d-icon-pencil-alt");
  await fillIn("#edit-title", "this is the new title");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(4);
  await click("#topic-title .submit-edit");

  assert.equal(
    find("#topic-title .badge-category").text(),
    "faq",
    "it displays the new category"
  );
  assert.equal(
    find(".fancy-title")
      .text()
      .trim(),
    "this is the new title",
    "it displays the new title"
  );
});

QUnit.test("Marking a topic as wiki", async assert => {
  await visit("/t/internationalization-localization/280");

  assert.ok(find("a.wiki").length === 0, "it does not show the wiki icon");

  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".topic-post:eq(0) button.show-post-admin-menu");
  await click(".btn.wiki");

  assert.ok(find("a.wiki").length === 1, "it shows the wiki icon");
});

QUnit.test("Visit topic routes", async assert => {
  await visit("/t/12");

  assert.equal(
    find(".fancy-title")
      .text()
      .trim(),
    "PM for testing",
    "it routes to the right topic"
  );

  await visit("/t/280/20");

  assert.equal(
    find(".fancy-title")
      .text()
      .trim(),
    "Internationalization / localization",
    "it routes to the right topic"
  );
});

QUnit.test("Updating the topic title with emojis", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-title .d-icon-pencil-alt");

  await fillIn("#edit-title", "emojis title :bike: :blonde_woman:t6:");

  await click("#topic-title .submit-edit");

  assert.equal(
    find(".fancy-title")
      .html()
      .trim(),
    `emojis title <img src="/images/emoji/emoji_one/bike.png?v=${v}" title="bike" alt="bike" class="emoji"> <img src="/images/emoji/emoji_one/blonde_woman/6.png?v=${v}" title="blonde_woman:t6" alt="blonde_woman:t6" class="emoji">`,
    "it displays the new title with emojis"
  );
});

QUnit.test("Updating the topic title with unicode emojis", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-title .d-icon-pencil-alt");

  await fillIn("#edit-title", "emojis title 👨‍🌾🙏");

  await click("#topic-title .submit-edit");

  assert.equal(
    find(".fancy-title")
      .html()
      .trim(),
    `emojis title <img src="/images/emoji/emoji_one/man_farmer.png?v=${v}" title="man_farmer" alt="man_farmer" class="emoji"><img src="/images/emoji/emoji_one/pray.png?v=${v}" title="pray" alt="pray" class="emoji">`,
    "it displays the new title with escaped unicode emojis"
  );
});

QUnit.test(
  "Updating the topic title with unicode emojis without whitespaces",
  async assert => {
    Discourse.SiteSettings.enable_inline_emoji_translation = true;
    await visit("/t/internationalization-localization/280");
    await click("#topic-title .d-icon-pencil-alt");

    await fillIn("#edit-title", "Test🙂Title");

    await click("#topic-title .submit-edit");

    assert.equal(
      find(".fancy-title")
        .html()
        .trim(),
      `Test<img src="/images/emoji/emoji_one/slightly_smiling_face.png?v=${v}" title="slightly_smiling_face" alt="slightly_smiling_face" class="emoji">Title`,
      "it displays the new title with escaped unicode emojis"
    );
  }
);

QUnit.skip("Deleting a topic", async assert => {
  await visit("/t/internationalization-localization/280");
  await click(".topic-post:eq(0) button.show-more-actions");
  await click(".widget-button.delete");

  assert.ok(exists(".widget-button.recover"), "it shows the recover button");
});

acceptance("Topic featured links", {
  loggedIn: true,
  settings: {
    topic_featured_link_enabled: true,
    max_topic_title_length: 80
  }
});

QUnit.test("remove featured link", async assert => {
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

  // this test only works in a browser:
  // await click('.title-wrapper .remove-featured-link');
  // await click('.title-wrapper .submit-edit');
  // assert.ok(!exists('.title-wrapper .topic-featured-link'), 'link is gone');
});

QUnit.test("Converting to a public topic", async assert => {
  await visit("/t/test-pm/34");
  assert.ok(exists(".private_message"));
  await click(".toggle-admin-menu");
  await click(".topic-admin-convert button");

  let categoryChooser = selectKit(".convert-to-public-topic .category-chooser");
  await categoryChooser.expand();
  await categoryChooser.selectRowByValue(21);

  await click(".convert-to-public-topic .btn-primary");
  assert.ok(!exists(".private_message"));
});

QUnit.test("Unpinning unlisted topic", async assert => {
  await visit("/t/internationalization-localization/280");

  await click(".toggle-admin-menu");
  await click(".topic-admin-pin .btn");
  await click(".btn-primary:last");

  await click(".toggle-admin-menu");
  await click(".topic-admin-visible .btn");

  await click(".toggle-admin-menu");
  assert.ok(exists(".topic-admin-pin"), "it should show the multi select menu");
});

QUnit.test("selecting posts", async assert => {
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

QUnit.test("select below", async assert => {
  await visit("/t/internationalization-localization/280");
  await click(".toggle-admin-menu");
  await click(".topic-admin-multi-select .btn");
  await click("#post_3 .select-below");

  assert.ok(
    find(".selected-posts")
      .html()
      .includes(I18n.t("topic.multi_select.description", { count: 18 })),
    "it should select the right number of posts"
  );

  await click("#post_2 .select-below");

  assert.ok(
    find(".selected-posts")
      .html()
      .includes(I18n.t("topic.multi_select.description", { count: 19 })),
    "it should select the right number of posts"
  );
});

QUnit.test("View Hidden Replies", async assert => {
  await visit("/t/internationalization-localization/280");
  await click(".gap");

  assert.equal(find(".gap").length, 0, "it hides gap");
});

QUnit.test("Quoting a quote keeps the original poster name", async assert => {
  await visit("/t/internationalization-localization/280");

  const selection = window.getSelection();
  const range = document.createRange();
  range.selectNodeContents($("#post_5 blockquote")[0]);
  selection.removeAllRanges();
  selection.addRange(range);

  await click(".quote-button");

  assert.ok(
    find(".d-editor-input")
      .val()
      .indexOf('quote="codinghorror said, post:3, topic:280"') !== -1
  );
});
