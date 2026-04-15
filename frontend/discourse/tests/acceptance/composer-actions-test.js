import { click, fillIn, visit, waitFor } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import Draft from "discourse/models/draft";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  selectText,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

function composerActionsDropdown() {
  return {
    async expand() {
      await click(".composer-actions-trigger");
    },
    async selectRowByValue(value) {
      await click(`[data-action-id='${value}']`);
    },
    rows() {
      return document.querySelectorAll(
        ".composer-actions-dropdown [data-action-id]"
      );
    },
    rowByIndex(index) {
      const rows = document.querySelectorAll(
        ".composer-actions-dropdown [data-action-id]"
      );
      const row = rows[index];
      return {
        value() {
          return row ? row.dataset.actionId : null;
        },
      };
    },
  };
}

acceptance(`Composer Actions`, function (needs) {
  needs.user({
    id: 5,
    username: "kris",
    whisperer: true,
  });
  needs.settings({
    prioritize_username_in_ux: true,
    display_name_on_posts: false,
  });
  needs.site({ can_tag_topics: true });
  needs.pretender((server, helper) => {
    server.put("/u/kris.json", () => helper.response({ user: {} }));
    const cardResponse = cloneJSON(userFixtures["/u/shade/card.json"]);
    server.get("/u/shade/card.json", () => helper.response(cardResponse));
    server.get("/c/shared-drafts/24/l/latest.json", () => {
      const response = cloneJSON(discoveryFixtures["/c/bug/1/l/latest.json"]);
      response.topic_list.can_create_topic = true;
      response.topic_list.filter = "c/shared-drafts/24/l/latest";

      return helper.response(response);
    });
  });

  test("replying to post", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");
    await composerActions.expand();

    assert.strictEqual(
      composerActions.rowByIndex(0).value(),
      "reply_as_new_topic"
    );
    assert.strictEqual(composerActions.rowByIndex(1).value(), "reply_to_topic");
    assert.strictEqual(composerActions.rows().length, 2);
  });

  test("replying to post - reply_to_topic", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");
    await fillIn(
      ".d-editor-input",
      "test replying to topic when initially replied to post"
    );

    await composerActions.expand();
    await composerActions.selectRowByValue("reply_to_topic");

    assert
      .dom(".action-title .topic-link")
      .hasText("Internationalization / localization");
    assert
      .dom(".action-title .topic-link")
      .hasAttribute("href", "/t/internationalization-localization/280");
    assert
      .dom(".d-editor-input")
      .hasValue("test replying to topic when initially replied to post");
  });

  test("toggle whisper via combo button menu for whisperers", async function (assert) {
    updateCurrentUser({ admin: false, moderator: false });
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert
      .dom(".composer-actions-trigger svg.d-icon-far-eye-slash")
      .doesNotExist("whisper icon is not visible");
    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .exists("reply icon is visible");

    await click(".d-combo-button .d-combo-button-menu");

    assert
      .dom(".composer-actions-trigger svg.d-icon-far-eye-slash")
      .exists("whisper icon is visible");
    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .doesNotExist("reply icon is not visible");
  });

  test("replying to post - reply_as_new_topic", async function (assert) {
    sinon.stub(Draft, "get").resolves({ draft: "", draft_sequence: 0 });

    const composerActions = composerActionsDropdown();
    const categoryChooser = selectKit(".title-wrapper .category-chooser");
    const categoryChooserReplyArea = selectKit(".reply-area .category-chooser");
    const quote = "test replying as new topic when initially replied to post";

    await visit("/t/internationalization-localization/280");

    await click("#topic-title .d-icon-pencil");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(4);
    await click("#topic-title .submit-edit");

    await click("article#post_3 button.reply");
    await fillIn(".d-editor-input", quote);

    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_new_topic");

    assert.strictEqual(categoryChooserReplyArea.header().name(), "faq");
    assert.dom(".d-editor-input").includesValue(quote);
  });

  test("reply_as_new_topic without a new_topic draft", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".create.reply");
    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_new_topic");
    assert.dom(".dialog-body").doesNotExist();
  });

  test("reply_as_new_topic without a permission to create topic", async function (assert) {
    updateCurrentUser({ can_create_topic: false });
    await visit("/t/internationalization-localization/280");
    await click(".create.reply");
    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    assert
      .dom(".composer-actions-dropdown [data-action-id='reply_as_new_topic']")
      .doesNotExist("reply as new topic option is not visible");
  });

  test("interactions", async function (assert) {
    const composerActions = composerActionsDropdown();
    const quote = "Life is like riding a bicycle.";

    await visit("/t/short-topic-with-two-posts/54077");
    await click("article#post_2 button.reply");
    await fillIn(".d-editor-input", quote);
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_to_topic");

    assert.dom(".action-title").hasText("Short topic with two posts");
    assert.dom(".d-editor-input").hasValue(quote);

    await composerActions.expand();

    assert.strictEqual(
      composerActions.rowByIndex(0).value(),
      "reply_as_new_topic"
    );
    assert.strictEqual(composerActions.rowByIndex(1).value(), "reply_to_post");
    assert.strictEqual(composerActions.rows().length, 2);

    await composerActions.selectRowByValue("reply_to_post");
    await composerActions.expand();

    assert.dom(".action-title img.avatar").exists();
    assert.dom(".action-title .user-link").hasText("tms");
    assert.dom(".d-editor-input").hasValue(quote);
    assert.strictEqual(
      composerActions.rowByIndex(0).value(),
      "reply_as_new_topic"
    );
    assert.strictEqual(composerActions.rowByIndex(1).value(), "reply_to_topic");
    assert.strictEqual(composerActions.rows().length, 2);

    await composerActions.selectRowByValue("reply_as_new_topic");
    await composerActions.expand();

    assert.dom(".d-editor-input").includesValue(quote);
    assert.strictEqual(composerActions.rowByIndex(0).value(), "reply_to_post");
    assert.strictEqual(composerActions.rowByIndex(1).value(), "reply_to_topic");
    assert.strictEqual(composerActions.rowByIndex(2).value(), "shared_draft");
    assert.strictEqual(
      composerActions.rowByIndex(3).value(),
      "create_private_message"
    );
    assert.strictEqual(composerActions.rows().length, 4);
  });

  test("new topic in shared drafts category opens shared draft composer", async function (assert) {
    await visit("/c/shared-drafts/24");

    assert.dom("#create-topic").hasText(i18n("topic.create_shared_draft"));

    await click("#create-topic");

    assert
      .dom("#reply-control .btn-primary.create .d-button-label")
      .hasText(i18n("composer.create_shared_draft"));
    assert
      .dom(".composer-actions svg.d-icon-far-clipboard")
      .exists("shared draft icon is visible");
    assert.strictEqual(
      selectKit(".category-chooser").header().value(),
      null,
      "shared drafts category is not selected as the destination category"
    );
  });

  test("interactions - private message", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click('#post_4 a[data-user-card="shade"]');
    await click(".usercard-controls .compose-pm .btn-primary");
    await composerActions.expand();

    assert.strictEqual(composerActions.rowByIndex(0).value(), "create_topic");
    assert.strictEqual(composerActions.rows().length, 1);
  });

  test("replying to post - toggle_topic_bump", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/short-topic-with-two-posts/54077");
    await click("article#post_2 button.reply");

    assert
      .dom(".composer-actions-trigger svg.d-icon-anchor")
      .doesNotExist("no-bump icon is not visible");
    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .exists("reply icon is visible");

    await composerActions.expand();
    await composerActions.selectRowByValue("toggle_topic_bump");

    assert
      .dom(".composer-actions-trigger svg.d-icon-anchor")
      .exists("no-bump icon is visible");
    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .doesNotExist("reply icon is not visible");

    await click(".composer-toggle-no-bump");

    assert
      .dom(".composer-actions-trigger svg.d-icon-anchor")
      .doesNotExist("no-bump icon is not visible");
    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .exists("reply icon is visible");
  });

  test("replying to post as staff", async function (assert) {
    const composerActions = composerActionsDropdown();

    updateCurrentUser({ admin: true });
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert.strictEqual(composerActions.rows().length, 4);
    assert.strictEqual(composerActions.rowByIndex(2).value(), "toggle_whisper");
    assert.strictEqual(
      composerActions.rowByIndex(3).value(),
      "toggle_topic_bump"
    );
  });

  test("replying to post as TL3 user", async function (assert) {
    const composerActions = composerActionsDropdown();

    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 3,
      whisperer: false,
      groups: [{ id: 13, name: "tl3_group" }],
    });
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert.strictEqual(composerActions.rows().length, 2);
    Array.from(composerActions.rows()).forEach((row) => {
      assert.notStrictEqual(
        row.dataset.actionId,
        "toggle_topic_bump",
        "toggle bump button is not visible"
      );
    });
  });

  test("replying to post as TL4 user", async function (assert) {
    const composerActions = composerActionsDropdown();

    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 4,
      whisperer: false,
      groups: [{ id: 13, name: "tl4_group" }],
    });
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert
      .dom(".d-combo-button .d-combo-button-menu")
      .exists("combo button menu is visible for TL4");

    await click(".d-combo-button .d-combo-button-menu");

    assert
      .dom(".composer-toggle-no-bump")
      .exists("no-bump toggle is visible for TL4");
  });

  test("editing post", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/t/internationalization-localization/280");
    await click("article#post_1 button.show-more-actions");
    await click("article#post_1 button.edit");
    await composerActions.expand();

    assert.strictEqual(composerActions.rows().length, 1);
    assert.strictEqual(composerActions.rowByIndex(0).value(), "reply_to_post");
  });

  test("trigger shows correct icon for reply mode", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert
      .dom(".composer-actions-trigger svg.d-icon-share")
      .exists("shows share icon when replying");
  });

  test("trigger shows correct icon for create topic mode", async function (assert) {
    await visit("/");
    await click("#create-topic");

    assert
      .dom(".composer-actions-trigger svg.d-icon-far-pen-to-square")
      .exists("shows pen-to-square icon when creating topic");
  });

  test("trigger shows correct icon for editing", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_1 button.show-more-actions");
    await click("article#post_1 button.edit");

    assert
      .dom(".composer-actions-trigger svg.d-icon-pencil")
      .exists("shows pencil icon when editing");
  });

  test("trigger shows correct label for reply mode", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("article#post_3 button.reply");

    assert
      .dom(".composer-actions-trigger")
      .hasText(
        i18n(
          "composer.composer_actions.reply_to_topic_composer_action.label"
        ).trim(),
        "shows reply label"
      );
  });

  test("trigger shows correct label for create topic mode", async function (assert) {
    await visit("/");
    await click("#create-topic");

    assert
      .dom(".composer-actions-trigger")
      .includesText(
        i18n("composer.composer_actions.create_topic.label"),
        "shows create topic label"
      );
  });

  test("create topic mode shows correct actions", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/");
    await click("#create-topic");
    await composerActions.expand();

    assert
      .dom(".composer-actions-dropdown [data-action-id='toggle_unlisted']")
      .exists("shows toggle unlisted action");
    assert
      .dom(
        ".composer-actions-dropdown [data-action-id='create_private_message']"
      )
      .exists("shows create private message action");
  });

  test("create topic mode does not show reply_as_new_topic", async function (assert) {
    const composerActions = composerActionsDropdown();

    await visit("/");
    await click("#create-topic");
    await composerActions.expand();

    assert
      .dom(".composer-actions-dropdown [data-action-id='reply_as_new_topic']")
      .doesNotExist("does not show reply_as_new_topic in create topic mode");
  });
});

function stubDraftResponse() {
  sinon.stub(Draft, "get").resolves({
    draft:
      '{"reply":"dum de dum da ba.","action":"createTopic","title":"dum da ba dum dum","categoryId":null,"archetypeId":"regular","metaData":null,"composerTime":540879,"typingTime":3400}',
    draft_sequence: 0,
  });
}

acceptance(`Composer Actions With New Topic Draft`, function (needs) {
  needs.user({ whisperer: true });

  needs.site({
    can_tag_topics: true,
  });

  test("shared draft", async function (assert) {
    updateCurrentUser({ draft_count: 1 });
    stubDraftResponse();

    await visit("/");
    await click("button.topic-drafts-menu-trigger");
    await waitFor(".topic-drafts-menu-content");
    await click(
      ".topic-drafts-menu-content .topic-drafts-item:first-child button"
    );

    await fillIn(
      "#reply-title",
      "This is the new text for the title using 'quotes'"
    );
    await fillIn(".d-editor-input", "This is the new text for the post");

    const tags = selectKit(".mini-tag-chooser");
    await tags.expand();
    await tags.selectRowByName("monkey");

    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    await composerActions.selectRowByValue("shared_draft");

    assert.strictEqual(tags.header().name(), "monkey", "tags are not reset");
    assert
      .dom("#reply-title")
      .hasValue("This is the new text for the title using 'quotes'");

    assert
      .dom("#reply-control .btn-primary.create .d-button-label")
      .hasText(i18n("composer.create_shared_draft"));
    assert
      .dom(".composer-actions-trigger svg.d-icon-far-clipboard")
      .exists("shared draft icon is visible");
  });

  test("reply_as_new_topic with new_topic draft", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".create.reply");

    stubDraftResponse();

    const composerActions = composerActionsDropdown();
    await composerActions.expand();
    await composerActions.selectRowByValue("reply_as_new_topic");

    assert
      .dom(".dialog-body")
      .hasText(i18n("composer.composer_actions.reply_as_new_topic.confirm"));
    await click(".dialog-footer .btn-primary");

    assert.dom(".d-editor-input").hasValue(/^Continuing the discussion from/);
  });
});

acceptance(`Prioritize Username`, function (needs) {
  needs.user();
  needs.settings({
    prioritize_username_in_ux: true,
    display_name_on_posts: false,
  });

  test("Reply to post use username", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await click("article#post_2 button.reply");

    assert.dom(".action-title .user-link").hasText("james_john");
  });

  test("Quotes use username", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await selectText("#post_2 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="james_john, post:2, topic:54079, full:true"]\nThis is a short topic.\n[/quote]\n\n'
      );
  });
});

acceptance(`Prioritize Full Name`, function (needs) {
  needs.user();
  needs.settings({
    prioritize_username_in_ux: false,
    display_name_on_posts: true,
  });

  test("Reply to post use full name", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await click("article#post_3 button.reply");

    assert
      .dom(".action-title .user-link")
      .hasHtml("&lt;h1&gt;Tim Stone&lt;/h1&gt;");
  });

  test("Quotes use full name", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await selectText("#post_2 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="james, john, the third, post:2, topic:54079, full:true, username:james_john"]\nThis is a short topic.\n[/quote]\n\n'
      );
  });

  test("Quoting a nested quote returns the correct username", async function (assert) {
    await visit("/t/short-topic-with-two-posts/54079");
    await selectText("#post_4 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="james_john, post:2, topic:54079"]\nThis is a short topic.\n[/quote]\n\n'
      );
  });
});

acceptance(`Prioritizing Name fall back`, function (needs) {
  needs.user();
  needs.settings({
    prioritize_username_in_ux: false,
    display_name_on_posts: true,
  });

  test("Quotes fall back to username if name is not present", async function (assert) {
    await visit("/t/internationalization-localization/130");
    // select a user with no name
    await selectText("#post_1 p");
    await click(".insert-quote");
    assert
      .dom(".d-editor-input")
      .hasValue(
        '[quote="bianca, post:1, topic:130, full:true"]\nLorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas a varius ipsum. Nunc euismod, metus non vulputate malesuada, ligula metus pharetra tortor, vel sodales arcu lacus sed mauris. Nam semper, orci vitae fringilla placerat, dui tellus convallis felis, ultricies laoreet sapien mi et metus. Mauris facilisis, mi fermentum rhoncus feugiat, dolor est vehicula leo, id porta leo ex non enim. In a ligula vel tellus commodo scelerisque non in ex. Pellentesque semper leo quam, nec varius est viverra eget. Donec vehicula sem et massa faucibus tempus.\n[/quote]\n\n'
      );
  });
});
