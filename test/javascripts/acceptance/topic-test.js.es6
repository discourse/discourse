import { acceptance } from "helpers/qunit-helpers";
import { IMAGE_VERSION as v } from "pretty-text/emoji";

acceptance("Topic", {
  loggedIn: true,
  pretend(server, helper) {
    server.put("/posts/398/wiki", () => {
      return helper.response({});
    });

    server.get("/topics/feature_stats.json", () => {
      return helper.response({
        pinned_in_category_count: 0,
        pinned_globally_count: 0,
        banner_count: 0
      });
    });

    server.put("/t/280/make-banner", () => {
      return helper.response({});
    });
  }
});

QUnit.test("Share Popup", async assert => {
  await visit("/t/internationalization-localization/280");
  assert.ok(!exists("#share-link.visible"), "it is not visible");

  await click("button[data-share-url]");
  assert.ok(exists("#share-link.visible"), "it shows the popup");

  await click("#share-link .close-share");
  assert.ok(!exists("#share-link.visible"), "it closes the popup");

  // TODO tgxworld This fails on Travis but we need to push the security fix out
  // first.
  // click('#topic-footer-buttons .btn.create');
  // fillIn('.d-editor-input', '<h2><div data-share-url="something">Click</button><h2>');
  //
  // click('#reply-control .btn.create');
  // click('h2 div[data-share-url]');
  //
  // andThen(() => {
  //   ok(!exists('#share-link.visible'), 'it does not show the popup');
  // });
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

QUnit.test("Reply as new topic", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("button.share:eq(0)");
  await click(".reply-as-new-topic a");

  assert.ok(exists(".d-editor-input"), "the composer input is visible");

  assert.equal(
    find(".d-editor-input")
      .val()
      .trim(),
    `Continuing the discussion from [Internationalization / localization](${
      window.location.origin
    }/t/internationalization-localization/280):`,
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
    `Continuing the discussion from [PM for testing](${
      window.location.origin
    }/t/pm-for-testing/12):`,
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

acceptance("Topic featured links", {
  loggedIn: true,
  settings: {
    topic_featured_link_enabled: true,
    max_topic_title_length: 80
  }
});

QUnit.test("remove featured link", async assert => {
  await visit("/t/299/1");
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

  await click(".toggle-admin-menu");

  assert.ok(
    exists(".selected-posts.hidden"),
    "it should hide the multi select menu"
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
