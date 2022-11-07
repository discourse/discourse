import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import { module } from "qunit";

const user = {
  id: 1,
  username: "markvanlan",
  name: null,
  avatar_template: "/letter_avatar_proxy/v4/letter/m/48db29/{size}.png",
};

module("Discourse Chat | Component | chat-user-avatar", function (hooks) {
  setupRenderingTest(hooks);

  componentTest("user is not online", {
    template: hbs`{{chat-user-avatar chat=chat user=user}}`,

    async beforeEach() {
      this.set("user", user);
      this.set("chat", { presenceChannel: { users: [] } });
    },

    async test(assert) {
      assert.ok(
        exists(
          `.chat-user-avatar .chat-user-avatar-container[data-user-card=${user.username}] .avatar[title=${user.username}]`
        )
      );
      assert.notOk(exists(".chat-user-avatar.is-online"));
    },
  });

  componentTest("user is online", {
    template: hbs`{{chat-user-avatar chat=chat user=user}}`,

    async beforeEach() {
      this.set("user", user);
      this.set("chat", {
        presenceChannel: { users: [{ id: user.id }] },
      });
    },

    async test(assert) {
      assert.ok(
        exists(
          `.chat-user-avatar .chat-user-avatar-container[data-user-card=${user.username}] .avatar[title=${user.username}]`
        )
      );
      assert.ok(exists(".chat-user-avatar.is-online"));
    },
  });
});
