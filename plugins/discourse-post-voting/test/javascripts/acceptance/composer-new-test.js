import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

let createAsPostVotingSetInRequest = false;

acceptance("composer (new composer actions)", function (needs) {
  needs.user();
  needs.settings({
    post_voting_enabled: true,
    enable_new_composer_actions: true,
  });

  needs.hooks.afterEach(function () {
    createAsPostVotingSetInRequest = false;
  });

  needs.pretender((server, helper) => {
    server.post("/posts", (request) => {
      const data = parsePostData(request.requestBody);
      if (
        String(data.create_as_post_voting) === "true" ||
        String(data.only_post_voting_in_this_category) === "true"
      ) {
        createAsPostVotingSetInRequest = true;
      }

      return helper.response({
        post: {
          topic_id: 280,
        },
      });
    });
  });

  test("Creating new topic with post voting format", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".composer-actions-trigger");
    await click("[data-action-id='togglePostVoting']");

    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.create_post_voting.label"),
        "displays the right composer action title when creating Post Voting topic"
      );

    assert
      .dom(".create .d-button-label")
      .hasText(
        i18n("composer.create_post_voting.label"),
        "displays the right label for composer create button"
      );

    await click(".composer-actions-trigger");
    await click("[data-action-id='togglePostVoting']");

    assert
      .dom(".composer-actions-trigger")
      .doesNotIncludeText(
        i18n("composer.create_post_voting.label"),
        "reverts to original composer title when post voting format is disabled"
      );

    await click(".composer-actions-trigger");
    await click("[data-action-id='togglePostVoting']");

    await fillIn("#reply-title", "this is some random topic title");
    await fillIn(".d-editor-input", "this is some random body");
    await click(".create");

    assert.true(
      createAsPostVotingSetInRequest,
      "submits the right request to create topic as Post Voting formatted"
    );
  });

  test("Creating new topic in category with Post Voting create default", async function (assert) {
    Category.findById(2).set("create_as_post_voting_default", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".composer-actions-trigger")
      .includesText(i18n("composer.create_post_voting.label"));
  });

  test("Creating new topic in category with only_post_voting_in_this_category enabled", async function (assert) {
    const category = Category.findById(2);
    category.set("only_post_voting_in_this_category", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();

    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".composer-actions-trigger")
      .includesText(i18n("composer.create_post_voting.label"));
  });
});

let restrictedCreateTopicPayload = null;

acceptance("composer (restricted post voting categories)", function (needs) {
  needs.user();
  needs.settings({
    post_voting_enabled: true,
    enable_new_composer_actions: true,
    post_voting_category_mode: "opt_in",
  });

  needs.hooks.afterEach(function () {
    restrictedCreateTopicPayload = null;
  });

  // `post_voting_allowed` is what the server resolves from the category
  // override, its ancestors, and the mode.
  function allowPostVoting(categoryId) {
    Category.findById(categoryId).set("post_voting_allowed", true);
  }

  needs.pretender((server, helper) => {
    server.post("/posts", (request) => {
      restrictedCreateTopicPayload = parsePostData(request.requestBody);

      return helper.response({
        post: {
          topic_id: 280,
        },
      });
    });
  });

  test("hides the post voting toggle for a disallowed category", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".composer-actions-trigger");

    assert
      .dom("[data-action-id='togglePostVoting']")
      .doesNotExist(
        "does not show the post voting action for a disallowed category"
      );
  });

  test("shows the post voting toggle for an allowed category", async function (assert) {
    allowPostVoting(5);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(5);

    await click(".composer-actions-trigger");

    assert
      .dom("[data-action-id='togglePostVoting']")
      .exists("shows the post voting action for an allowed category");
  });

  test("does not force post voting default in a disallowed category", async function (assert) {
    Category.findById(2).set("create_as_post_voting_default", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".composer-actions-trigger")
      .doesNotIncludeText(
        i18n("composer.create_post_voting.label"),
        "does not default to post voting for a disallowed category"
      );
  });

  test("does not force post voting in a disallowed category that is post voting only", async function (assert) {
    Category.findById(2).set("only_post_voting_in_this_category", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".composer-actions-trigger")
      .doesNotIncludeText(
        i18n("composer.create_post_voting.label"),
        "does not force post voting for a disallowed category"
      );

    await fillIn("#reply-title", "this is some random topic title");
    await fillIn(".d-editor-input", "this is some random body");
    await click(".create");

    assert.strictEqual(
      String(restrictedCreateTopicPayload.only_post_voting_in_this_category),
      "false",
      "does not submit the topic as Post Voting formatted"
    );
  });

  test("turns post voting off when moving to a disallowed category", async function (assert) {
    allowPostVoting(5);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(5);

    await click(".composer-actions-trigger");
    await click("[data-action-id='togglePostVoting']");

    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.create_post_voting.label"),
        "post voting is enabled while an allowed category is selected"
      );

    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".composer-actions-trigger")
      .doesNotIncludeText(
        i18n("composer.create_post_voting.label"),
        "post voting is turned off after switching to a disallowed category"
      );

    await fillIn("#reply-title", "this is some random topic title");
    await fillIn(".d-editor-input", "this is some random body");
    await click(".create");

    assert.strictEqual(
      String(restrictedCreateTopicPayload.create_as_post_voting),
      "false",
      "does not submit the topic as Post Voting formatted"
    );
  });

  test("shows the post voting toggle for a subcategory the server resolved as allowed", async function (assert) {
    allowPostVoting(22);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(22);

    await click(".composer-actions-trigger");

    assert
      .dom("[data-action-id='togglePostVoting']")
      .exists("a subcategory that inherits its parent's opt-in");
  });

  test("submits the topic as Post Voting formatted in an allowed category", async function (assert) {
    allowPostVoting(5);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(5);

    await click(".composer-actions-trigger");
    await click("[data-action-id='togglePostVoting']");

    await fillIn("#reply-title", "this is some random topic title");
    await fillIn(".d-editor-input", "this is some random body");
    await click(".create");

    assert.strictEqual(
      String(restrictedCreateTopicPayload.create_as_post_voting),
      "true",
      "submits the topic as Post Voting formatted"
    );
  });
});

acceptance("composer (post voting opt out mode)", function (needs) {
  needs.user();
  needs.settings({
    post_voting_enabled: true,
    enable_new_composer_actions: true,
    post_voting_category_mode: "opt_out",
  });

  test("shows the post voting toggle for a category that has not opted out", async function (assert) {
    Category.findById(2).set("post_voting_allowed", true);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    await click(".composer-actions-trigger");

    assert
      .dom("[data-action-id='togglePostVoting']")
      .exists("opt out mode allows post voting by default");
  });

  test("hides the post voting toggle for a category that has opted out", async function (assert) {
    Category.findById(5).set("post_voting_allowed", false);

    await visit("/");
    await click("#create-topic");

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(5);

    await click(".composer-actions-trigger");

    assert
      .dom("[data-action-id='togglePostVoting']")
      .doesNotExist("the category opted out");
  });
});
