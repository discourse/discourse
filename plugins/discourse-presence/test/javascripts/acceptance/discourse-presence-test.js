import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import User from "discourse/models/user";
import {
  joinChannel,
  leaveChannel,
  presentUserIds,
} from "discourse/tests/helpers/presence-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Presence Plugin", function (needs) {
  needs.user({ whisperer: true });

  test("Doesn't break topic creation", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const categoryChooser = selectKit(".category-chooser");
    await categoryChooser.expand();
    await categoryChooser.selectRowByValue(2);
    await fillIn("#reply-title", "Internationalization Localization");
    await fillIn(
      ".d-editor-input",
      "this is the *content* of a new topic post"
    );
    await click("#reply-control button.create");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "transitions to the newly created topic URL"
    );
  });

  test("Publishes own reply presence", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .btn.create");
    assert.dom(".d-editor-input").exists("the composer input is visible");

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [],
      "does not publish presence for open composer"
    );

    await fillIn(".d-editor-input", "this is the content of my reply");

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [User.current().id],
      "publishes presence when typing"
    );

    await click("#reply-control button.create");

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [],
      "leaves channel when composer closes"
    );
  });

  test("Uses whisper channel for whispers", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .btn.create");
    assert.dom(".d-editor-input").exists("the composer input is visible");

    await fillIn(".d-editor-input", "this is the content of my reply");

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [User.current().id],
      "publishes reply presence when typing"
    );

    const menu = selectKit(".toolbar-popup-menu-options");
    await menu.expand();
    await menu.selectRowByName("toggle-whisper");

    assert
      .dom(".composer-actions svg.d-icon-far-eye-slash")
      .exists("sets the post type to whisper");

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [],
      "removes reply presence"
    );

    assert.deepEqual(
      presentUserIds("/discourse-presence/whisper/280"),
      [User.current().id],
      "adds whisper presence"
    );

    await click("#reply-control button.create");

    assert.deepEqual(
      presentUserIds("/discourse-presence/whisper/280"),
      [],
      "leaves whisper channel when composer closes"
    );
  });

  test("Uses the edit channel for editing", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click(".topic-post:nth-of-type(1) button.show-more-actions");
    await click(".topic-post:nth-of-type(1) button.edit");

    assert
      .dom(".d-editor-input")
      .hasValue(
        document.querySelector(".topic-post:nth-of-type(1) .cooked > p")
          .innerText,
        "composer has contents of post to be edited"
      );

    assert.deepEqual(
      presentUserIds("/discourse-presence/edit/398"),
      [],
      "is not present when composer first opened"
    );

    await fillIn(".d-editor-input", "some edited content");

    assert.deepEqual(
      presentUserIds("/discourse-presence/edit/398"),
      [User.current().id],
      "becomes present in the edit channel"
    );

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [],
      "is not made present in the reply channel"
    );

    assert.deepEqual(
      presentUserIds("/discourse-presence/whisper/280"),
      [],
      "is not made present in the whisper channel"
    );
  });

  test("Displays replying and whispering presence at bottom of topic", async function (assert) {
    await visit("/t/internationalization-localization/280");

    const avatarSelector =
      ".topic-above-footer-buttons-outlet.presence .presence-avatars .avatar";
    assert
      .dom(".topic-above-footer-buttons-outlet.presence")
      .exists("includes the presence component");
    assert.dom(avatarSelector).doesNotExist("no avatars displayed");

    await joinChannel("/discourse-presence/reply/280", {
      id: 123,
      avatar_template: "/images/avatar.png",
      username: "my-username",
    });

    assert.dom(avatarSelector).exists({ count: 1 }, "avatar displayed");

    await joinChannel("/discourse-presence/whisper/280", {
      id: 124,
      avatar_template: "/images/avatar.png",
      username: "my-username2",
    });

    assert.dom(avatarSelector).exists({ count: 2 }, "whisper avatar displayed");

    await leaveChannel("/discourse-presence/reply/280", {
      id: 123,
    });

    assert.dom(avatarSelector).exists({ count: 1 }, "reply avatar removed");

    await leaveChannel("/discourse-presence/whisper/280", {
      id: 124,
    });

    assert.dom(avatarSelector).doesNotExist("whisper avatar removed");
  });

  test("Displays replying and whispering presence in composer", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    assert.dom(".d-editor-input").exists("the composer input is visible");

    const avatarSelector = ".reply-to .presence-avatars .avatar";
    assert.dom(avatarSelector).doesNotExist("no avatars displayed");

    await joinChannel("/discourse-presence/reply/280", {
      id: 123,
      avatar_template: "/images/avatar.png",
      username: "my-username",
    });

    assert.dom(avatarSelector).exists({ count: 1 }, "avatar displayed");

    await joinChannel("/discourse-presence/whisper/280", {
      id: 124,
      avatar_template: "/images/avatar.png",
      username: "my-username2",
    });

    assert.dom(avatarSelector).exists({ count: 2 }, "whisper avatar displayed");

    await leaveChannel("/discourse-presence/reply/280", {
      id: 123,
    });

    assert.dom(avatarSelector).exists({ count: 1 }, "reply avatar removed");

    await leaveChannel("/discourse-presence/whisper/280", {
      id: 124,
    });

    assert.dom(avatarSelector).doesNotExist("whisper avatar removed");
  });
});
