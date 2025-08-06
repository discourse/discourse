import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Category from "discourse/models/category";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

let createAsPostVotingSetInRequest = false;

acceptance("Discourse Post Voting - composer", function (needs) {
  needs.user();
  needs.settings({ post_voting_enabled: true });

  needs.hooks.afterEach(function () {
    createAsPostVotingSetInRequest = false;
  });

  needs.pretender((server, helper) => {
    server.post("/posts", (request) => {
      if (
        parsePostData(request.requestBody).create_as_post_voting === "true" ||
        parsePostData(request.requestBody).only_post_voting_in_this_category ===
          "true"
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

    const composerActions = selectKit(".composer-actions");
    await composerActions.expand();
    await composerActions.selectKitSelectRowByName(
      i18n("composer.composer_actions.create_as_post_voting.label")
    );

    assert
      .dom(".action-title")
      .hasText(
        i18n("composer.create_post_voting.label"),
        "displays the right composer action title when creating Post Voting topic"
      );

    assert
      .dom(".create .d-button-label")
      .hasText(
        i18n("composer.create_post_voting.label"),
        "displays the right label for composer create button"
      );

    await composerActions.expand();
    await composerActions.selectKitSelectRowByName(
      i18n("composer.composer_actions.remove_as_post_voting.label")
    );

    assert
      .dom(".action-title")
      .doesNotIncludeText(
        i18n("composer.create_post_voting.label"),
        "reverts to original composer title when post voting format is disabled"
      );

    await composerActions.expand();
    await composerActions.selectKitSelectRowByName(
      i18n("composer.composer_actions.create_as_post_voting.label")
    );

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

    assert.dom(".action-title").hasText(i18n("topic.create_long"));

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);

    assert
      .dom(".action-title")
      .hasText(i18n("composer.create_post_voting.label"));
  });

  test("Creating new topic in category with only_post_voting_in_this_category enabled", async function (assert) {
    const category = Category.findById(2);
    category.set("only_post_voting_in_this_category", true);

    await visit("/");
    await click("#create-topic");

    assert.dom(".action-title").hasText(i18n("topic.create_long"));

    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();

    await categoryChooser.selectRowByValue(2);
    const newTopicType = selectKit(".dropdown-select-box");
    await newTopicType.expand();
    assert
      .dom(".action-title")
      .hasText(i18n("composer.create_post_voting.label"));
  });
});
