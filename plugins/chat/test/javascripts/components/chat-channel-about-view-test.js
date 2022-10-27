import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import fabricators from "../helpers/fabricators";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import I18n from "I18n";

module(
  "Discourse Chat | Component | chat-channel-about-view | admin user",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set(
        "channel",
        fabricators.chatChannel({ chatable_type: "Category" })
      );
      this.channel.set("description", "foo");
      this.currentUser.set("admin", true);
      this.currentUser.set("has_chat_enabled", true);
      this.siteSettings.chat_enabled = true;
    });

    test("chatable name", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.equal(
        query(".category-name").innerText,
        this.channel.chatable.name
      );
    });

    test("chatable description", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.equal(
        query(".category-name").innerText,
        this.channel.chatable.name
      );

      this.channel.set("description", null);
      await settled();

      assert.equal(
        query(".channel-info-about-view__description__helper-text").innerText,
        I18n.t("chat.channel_edit_description_modal.description")
      );
    });

    test("edit title", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.ok(exists(".edit-title-btn"));
    });

    test("edit description", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.ok(exists(".edit-description-btn"));
    });

    test("join", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.ok(exists(".toggle-channel-membership-button.-join"));
    });

    test("leave", async function (assert) {
      this.channel.current_user_membership.set("following", true);
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.ok(exists(".toggle-channel-membership-button.-leave"));
    });
  }
);

module(
  "Discourse Chat | Component | chat-channel-about-view | regular user",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set(
        "channel",
        fabricators.chatChannel({ chatable_type: "Category" })
      );
      this.channel.set("description", "foo");
      this.currentUser.set("has_chat_enabled", true);
      this.siteSettings.chat_enabled = true;
    });

    test("escapes channel title", async function (assert) {
      this.channel.set("title", "<div class='xss'>evil</div>");

      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.notOk(exists(".xss"));
    });

    test("chatable name", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.equal(
        query(".category-name").innerText,
        this.channel.chatable.name
      );
    });

    test("chatable description", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.equal(
        query(".category-name").innerText,
        this.channel.chatable.name
      );

      this.channel.set("description", null);
      await settled();

      assert.notOk(exists(".channel-info-about-view__description"));
    });

    test("edit title", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.notOk(exists(".edit-title-btn"));
    });

    test("edit description", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.notOk(exists(".edit-description-btn"));
    });

    test("join", async function (assert) {
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.ok(exists(".toggle-channel-membership-button.-join"));
    });

    test("leave", async function (assert) {
      this.channel.current_user_membership.set("following", true);
      await render(hbs`{{chat-channel-about-view channel=channel}}`);

      assert.ok(exists(".toggle-channel-membership-button.-leave"));
    });
  }
);
