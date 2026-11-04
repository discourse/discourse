import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import ChatUserAvatar from "discourse/plugins/chat/discourse/components/chat-user-avatar";

function containerSelector(user, options = {}) {
  let onlineSelector = ":not(.is-online)";
  if (options.online) {
    onlineSelector = ".is-online";
  }

  return `.chat-user-avatar${onlineSelector} .chat-user-avatar__container[data-user-card=${user.username}] .avatar[title=${user.username}]`;
}

module("Component | <ChatUserAvatar />", function (hooks) {
  setupRenderingTest(hooks);

  test("when user is not online", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = { presenceChannel: { users: [] } };

    await render(
      <template>
        <ChatUserAvatar @chat={{this.chat}} @user={{this.user}} />
      </template>
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("user is online", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      <template>
        <ChatUserAvatar @chat={{this.chat}} @user={{this.user}} />
      </template>
    );

    assert.dom(containerSelector(this.user, { online: true })).exists();
  });

  test("user has avatar flair", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.user.setProperties({
      flair_group_id: 42,
      flair_name: "test_group",
      flair_url: "bars",
    });

    await render(<template><ChatUserAvatar @user={{this.user}} /></template>);

    assert
      .dom(".chat-user-avatar__container .avatar-flair-test_group .d-icon-bars")
      .exists("the user's flair is shown on the avatar");
  });

  test("@showPresence=false", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();
    this.chat = {
      presenceChannel: { users: [{ id: this.user.id }] },
    };

    await render(
      <template>
        <ChatUserAvatar
          @chat={{this.chat}}
          @showPresence={{false}}
          @user={{this.user}}
        />
      </template>
    );

    assert.dom(containerSelector(this.user, { online: false })).exists();
  });

  test("@interactive=true", async function (assert) {
    this.user = new CoreFabricators(getOwner(this)).user();

    await render(
      <template>
        <ChatUserAvatar @interactive={{false}} @user={{this.user}} />
      </template>
    );

    assert.dom(".clickable").doesNotExist();
  });

  test("bot avatar flair follows the palette even with chat icon styles", async function (assert) {
    const user = new CoreFabricators(this.owner).user({ id: -1201 });

    await render(
      <template>
        <div class="light-palette" style="--primary: #222; --secondary: #fff;">
          <ChatUserAvatar @user={{user}} />
        </div>
        <div class="dark-palette" style="--primary: #eee; --secondary: #111;">
          <ChatUserAvatar @interactive={{false}} @user={{user}} />
        </div>
      </template>
    );

    for (const selector of [".light-palette", ".dark-palette"]) {
      assert
        .dom(`${selector} .avatar-flair.--bot`)
        .hasAttribute(
          "aria-label",
          i18n("user.bot_account"),
          "chat exposes the translated marker"
        );
      assert
        .dom(`${selector} .d-icon-robot`)
        .exists("chat renders the default robot icon");
    }
    assert
      .dom(".light-palette .avatar-flair")
      .hasStyle(
        { backgroundColor: "rgb(34, 34, 34)" },
        "the light palette provides the badge surface"
      );
    assert
      .dom(".light-palette .d-icon-robot")
      .hasStyle(
        { fill: "rgb(255, 255, 255)" },
        "chat styles preserve icon contrast in the light palette"
      );
    assert
      .dom(".dark-palette .avatar-flair")
      .hasStyle(
        { backgroundColor: "rgb(238, 238, 238)" },
        "the dark palette provides the badge surface"
      );
    assert
      .dom(".dark-palette .d-icon-robot")
      .hasStyle(
        { fill: "rgb(17, 17, 17)" },
        "chat styles preserve icon contrast in the dark palette"
      );
  });

  test("AI flair wins over the robot fallback in chat", async function (assert) {
    const user = new CoreFabricators(this.owner).user({ id: -1201 });
    user.setProperties({
      flair_group_id: 42,
      flair_name: "discourse_ai_users",
      flair_url: "discourse-ai",
    });

    await render(<template><ChatUserAvatar @user={{user}} /></template>);

    assert
      .dom(".avatar-flair .d-icon-discourse-ai")
      .exists("chat preserves the configured AI mark");
    assert
      .dom(".avatar-flair.--bot")
      .doesNotExist("chat does not stack a default bot mark");
  });
});
