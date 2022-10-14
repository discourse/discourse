import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { visit } from "@ember/test-helpers";
import Site from "discourse/models/site";

acceptance("Welcome Topic Banner", function (needs) {
  needs.user({ admin: true });
  needs.site({ show_welcome_topic_banner: true });

  test("Is shown on latest", async function (assert) {
    await visit("/latest");
    assert.ok(exists(".welcome-cta"), "has the welcome topic banner");
    assert.ok(
      exists("button.welcome-cta__button"),
      "has the welcome topic edit button"
    );
  });

  test("Does not show if edited", async function (assert) {
    const site = Site.current();
    site.set("show_welcome_topic_banner", false);

    await visit("/latest");
    assert.ok(!exists(".welcome-cta"), "has the welcome topic banner");
  });

  test("Does not show on latest with query param tracked present", async function (assert) {
    await visit("/latest?f=tracked");
    assert.ok(
      !exists(".welcome-cta"),
      "does not have the welcome topic banner"
    );
  });

  test("Does not show on latest with query param watched present", async function (assert) {
    await visit("/latest?f=watched");
    assert.ok(
      !exists(".welcome-cta"),
      "does not have the welcome topic banner"
    );
  });

  test("Does not show on /categories page", async function (assert) {
    await visit("/categories");
    assert.ok(
      !exists(".welcome-cta"),
      "does not have the welcome topic banner"
    );
  });

  test("Does not show on /top page", async function (assert) {
    await visit("/top");
    assert.ok(
      !exists(".welcome-cta"),
      "does not have the welcome topic banner"
    );
  });

  test("Does not show on /unseen page", async function (assert) {
    await visit("/unseen");
    assert.ok(
      !exists(".welcome-cta"),
      "does not have the welcome topic banner"
    );
  });
});
