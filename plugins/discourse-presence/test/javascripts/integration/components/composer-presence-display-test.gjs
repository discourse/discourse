import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import Composer from "discourse/models/composer";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  joinChannel,
  leaveChannel,
} from "discourse/tests/helpers/presence-pretender";
import ComposerPresenceDisplay from "discourse/plugins/discourse-presence/discourse/components/composer-presence-display";

module("Integration | Component | composer-presence-display", function (hooks) {
  setupRenderingTest(hooks);

  test("uses translate channel for translation editing", async function (assert) {
    const model = {
      action: Composer.ADD_TRANSLATION,
      post: { id: 123 },
      topic: { id: 456 },
      replyDirty: false,
    };

    this.set("model", model);

    await render(
      <template><ComposerPresenceDisplay @model={{this.model}} /></template>
    );

    assert
      .dom(".presence-users")
      .doesNotExist("no presence users shown initially");

    await joinChannel("/discourse-presence/translate/123", {
      id: 999,
      avatar_template: "/images/avatar.png",
      username: "translator",
    });

    assert
      .dom(".presence-users")
      .exists("presence users displayed when someone else is translating");

    assert
      .dom(".presence-avatars .avatar")
      .exists({ count: 1 }, "one avatar displayed");

    assert
      .dom(".presence-text .description")
      .hasText("translating", "shows 'translating' text");

    await leaveChannel("/discourse-presence/translate/123", { id: 999 });

    assert
      .dom(".presence-users")
      .doesNotExist("presence hidden after user leaves");
  });

  test("translate and edit channels are separate", async function (assert) {
    const translationModel = {
      action: Composer.ADD_TRANSLATION,
      post: { id: 123 },
      topic: { id: 456 },
      replyDirty: false,
    };

    this.set("model", translationModel);
    await render(
      <template><ComposerPresenceDisplay @model={{this.model}} /></template>
    );

    await joinChannel("/discourse-presence/edit/123", {
      id: 888,
      avatar_template: "/images/avatar.png",
      username: "editor",
    });

    assert
      .dom(".presence-users")
      .doesNotExist("translator does not see editor (different channel)");

    await joinChannel("/discourse-presence/translate/123", {
      id: 999,
      avatar_template: "/images/avatar.png",
      username: "other_translator",
    });

    assert
      .dom(".presence-users")
      .exists("translator sees other translator (same channel)");

    assert
      .dom(".presence-avatars .avatar")
      .exists({ count: 1 }, "one translator avatar displayed");

    await leaveChannel("/discourse-presence/edit/123", { id: 888 });
    await leaveChannel("/discourse-presence/translate/123", { id: 999 });
  });

  test("shows 'translating' text for translate presence", async function (assert) {
    const model = {
      action: Composer.ADD_TRANSLATION,
      post: { id: 123 },
      topic: { id: 456 },
      replyDirty: false,
    };

    this.set("model", model);
    await render(
      <template><ComposerPresenceDisplay @model={{this.model}} /></template>
    );

    await joinChannel("/discourse-presence/translate/123", {
      id: 999,
      avatar_template: "/images/avatar.png",
      username: "translator",
    });

    assert
      .dom(".presence-text .description")
      .hasText("translating", "displays 'translating' for translate state");

    await leaveChannel("/discourse-presence/translate/123", { id: 999 });
  });
});
