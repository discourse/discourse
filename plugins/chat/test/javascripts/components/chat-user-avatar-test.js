import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import { render } from "@ember/test-helpers";

const user = {
  id: 1,
  username: "markvanlan",
  name: null,
  avatar_template: "/letter_avatar_proxy/v4/letter/m/48db29/{size}.png",
};

module("Discourse Chat | Component | chat-user-avatar", function (hooks) {
  setupRenderingTest(hooks);

  test("user is not online", async function (assert) {
    this.set("user", user);
    this.set("chat", { presenceChannel: { users: [] } });

    await render(
      hbs`<ChatUserAvatar @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.true(
      exists(
        `.chat-user-avatar .chat-user-avatar-container[data-user-card=${user.username}] .avatar[title=${user.username}]`
      )
    );
    assert.false(exists(".chat-user-avatar.is-online"));
  });

  test("user is online", async function (assert) {
    this.set("user", user);
    this.set("chat", {
      presenceChannel: { users: [{ id: user.id }] },
    });

    await render(
      hbs`<ChatUserAvatar @chat={{this.chat}} @user={{this.user}} />`
    );

    assert.true(
      exists(
        `.chat-user-avatar .chat-user-avatar-container[data-user-card=${user.username}] .avatar[title=${user.username}]`
      )
    );
    assert.true(exists(".chat-user-avatar.is-online"));
  });
});
