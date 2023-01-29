import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import EmberObject from "@ember/object";

module("Integration | Component | badge-title", function (hooks) {
  setupRenderingTest(hooks);

  test("badge title", async function (assert) {
    this.set("subject", selectKit());
    this.set("selectableUserBadges", [
      EmberObject.create({
        id: 0,
        badge: { name: "(none)" },
      }),
      EmberObject.create({
        id: 42,
        badge_id: 102,
        badge: { name: "Test" },
      }),
    ]);

    pretender.put("/u/eviltrout/preferences/badge_title", () => response({}));

    await render(hbs`
      <BadgeTitle @selectableUserBadges={{this.selectableUserBadges}} />
    `);

    await this.subject.expand();
    await this.subject.selectRowByValue(42);
    await click(".btn");

    assert.strictEqual(this.currentUser.title, "Test");
  });
});
