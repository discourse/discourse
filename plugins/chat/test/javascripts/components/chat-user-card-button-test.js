import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";
import { module, test } from "qunit";
import sinon from "sinon";
import CoreFabricators from "discourse/lib/fabricators";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Discourse Chat | Component | <Chat::DirectMessageButton />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("when current user can send direct messages", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
        .value(true);
      this.user = new CoreFabricators(getOwner(this)).user();

      await render(
        hbs`<Chat::DirectMessageButton @user={{this.user}} @modal={{true}} />`
      );

      assert.dom(".chat-direct-message-btn").exists("it shows the chat button");
    });

    test("when current user can’t send direct messages", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
        .value(false);
      this.user = new CoreFabricators(getOwner(this)).user();

      await render(
        hbs`<Chat::DirectMessageButton @user={{this.user}} @modal={{true}} />`
      );

      assert
        .dom(".chat-direct-message-btn")
        .doesNotExist("it doesn’t show the chat button");
    });

    test("when displayed user has disabled PMs / DMs", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
        .value(true);

      this.user = new CoreFabricators(getOwner(this)).user({
        can_send_private_message_to_user: false,
      });

      await render(
        hbs`<Chat::DirectMessageButton @user={{this.user}} @modal={{true}} />`
      );

      assert
        .dom(".chat-direct-message-btn")
        .doesNotExist("it doesn’t show the chat button");
    });
  }
);
