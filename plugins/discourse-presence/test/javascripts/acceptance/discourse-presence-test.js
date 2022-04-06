import {
  acceptance,
  count,
  exists,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { click, currentURL, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  joinChannel,
  leaveChannel,
  presentUserIds,
} from "discourse/tests/helpers/presence-pretender";
import User from "discourse/models/user";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Discourse Presence Plugin", function (needs) {
  needs.user();
  needs.settings({ enable_whispers: true });

  test("Doesn't break topic creation", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Internationalization Localization");
    await fillIn(
      ".d-editor-input",
      "this is the *content* of a new topic post"
    );
    await click("#reply-control button.create");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280",
      "it transitions to the newly created topic URL"
    );
  });

  test("Publishes own reply presence", async function (assert) {
    await visit("/t/internationalization-localization/280");

    await click("#topic-footer-buttons .btn.create");
    assert.ok(exists(".d-editor-input"), "the composer input is visible");

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
    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    await fillIn(".d-editor-input", "this is the content of my reply");

    assert.deepEqual(
      presentUserIds("/discourse-presence/reply/280"),
      [User.current().id],
      "publishes reply presence when typing"
    );

    const menu = selectKit(".toolbar-popup-menu-options");
    await menu.expand();
    await menu.selectRowByValue("toggleWhisper");

    assert.strictEqual(
      count(".composer-actions svg.d-icon-far-eye-slash"),
      1,
      "it sets the post type to whisper"
    );

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

    assert.strictEqual(
      queryAll(".d-editor-input").val(),
      queryAll(".topic-post:nth-of-type(1) .cooked > p").text(),
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
    assert.ok(
      exists(".topic-above-footer-buttons-outlet.presence"),
      "includes the presence component"
    );
    assert.strictEqual(count(avatarSelector), 0, "no avatars displayed");

    await joinChannel("/discourse-presence/reply/280", {
      id: 123,
      avatar_template: "/a/b/c.jpg",
      username: "myusername",
    });

    assert.strictEqual(count(avatarSelector), 1, "avatar displayed");

    await joinChannel("/discourse-presence/whisper/280", {
      id: 124,
      avatar_template: "/a/b/c.jpg",
      username: "myusername2",
    });

    assert.strictEqual(count(avatarSelector), 2, "whisper avatar displayed");

    await leaveChannel("/discourse-presence/reply/280", {
      id: 123,
    });

    assert.strictEqual(count(avatarSelector), 1, "reply avatar removed");

    await leaveChannel("/discourse-presence/whisper/280", {
      id: 124,
    });

    assert.strictEqual(count(avatarSelector), 0, "whisper avatar removed");
  });

  test("Displays replying and whispering presence in composer", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    assert.ok(exists(".d-editor-input"), "the composer input is visible");

    const avatarSelector = ".reply-to .presence-avatars .avatar";
    assert.strictEqual(count(avatarSelector), 0, "no avatars displayed");

    await joinChannel("/discourse-presence/reply/280", {
      id: 123,
      avatar_template: "/a/b/c.jpg",
      username: "myusername",
    });

    assert.strictEqual(count(avatarSelector), 1, "avatar displayed");

    await joinChannel("/discourse-presence/whisper/280", {
      id: 124,
      avatar_template: "/a/b/c.jpg",
      username: "myusername2",
    });

    assert.strictEqual(count(avatarSelector), 2, "whisper avatar displayed");

    await leaveChannel("/discourse-presence/reply/280", {
      id: 123,
    });

    assert.strictEqual(count(avatarSelector), 1, "reply avatar removed");

    await leaveChannel("/discourse-presence/whisper/280", {
      id: 124,
    });

    assert.strictEqual(count(avatarSelector), 0, "whisper avatar removed");
  });
});
