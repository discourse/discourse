import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import fabricators from "discourse/plugins/chat/discourse/lib/fabricators";

module(
  "Discourse Chat | Component | <Chat::UserCardButton />",
  function (hooks) {
    setupRenderingTest(hooks);

    test("when current user can send direct messages", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
        .value(true);
      this.user = fabricators.user();

      await render(hbs`<Chat::UserCardButton @user={{user}} />`);

      assert.dom(".chat-user-card-btn").exists("it shows the chat button");
    });

    test("when current user can’t send direct messages", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
        .value(false);
      this.user = fabricators.user();

      await render(hbs`<Chat::UserCardButton @user={{user}} />`);

      assert
        .dom(".chat-user-card-btn")
        .doesNotExist("it doesn’t show the chat button");
    });

    test("when displayed user is suspended", async function (assert) {
      sinon
        .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
        .value(true);

      this.user = fabricators.user({
        suspended_till: moment().add(1, "year").toDate(),
      });

      await render(hbs`<Chat::UserCardButton @user={{user}}/>`);

      assert
        .dom(".chat-user-card-btn")
        .doesNotExist("it doesn’t show the chat button");
    });
  }
);
