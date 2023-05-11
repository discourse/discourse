import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import User from "discourse/models/user";

module("Discourse Chat | Component | user-card-chat-button", function (hooks) {
  setupRenderingTest(hooks);

  test("when current user can send direct messages", async function (assert) {
    sinon
      .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
      .value(true);

    await render(hbs`<UserCardChatButton/>`);

    assert.true(exists(".user-card-chat-btn"), "it shows the chat button");
  });

  test("when current user can’t send direct messages", async function (assert) {
    sinon
      .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
      .value(false);

    await render(hbs`<UserCardChatButton/>`);

    assert.false(
      exists(".user-card-chat-btn"),
      "it doesn’t show the chat button"
    );
  });

  test("when displayed user is suspended", async function (assert) {
    sinon
      .stub(this.owner.lookup("service:chat"), "userCanDirectMessage")
      .value(true);

    this.user = User.create({
      suspended_till: moment().add(1, "year").toDate(),
    });

    await render(hbs`<UserCardChatButton @user={{user}}/>`);

    assert.false(
      exists(".user-card-chat-btn"),
      "it doesn’t show the chat button"
    );
  });
});
