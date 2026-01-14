import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BadgeTitle from "discourse/components/badge-title";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | badge-title", function (hooks) {
  setupRenderingTest(hooks);

  test("badge title", async function (assert) {
    const subject = selectKit();
    const selectableUserBadges = [
      EmberObject.create({
        id: 0,
        badge: { name: "(none)" },
      }),
      EmberObject.create({
        id: 42,
        badge_id: 102,
        badge: { name: "Test" },
      }),
    ];

    pretender.put("/u/eviltrout/preferences/badge_title", () => response({}));

    await render(
      <template>
        <BadgeTitle @selectableUserBadges={{selectableUserBadges}} />
      </template>
    );

    await subject.expand();
    await subject.selectRowByValue(42);
    await click(".btn");

    assert.strictEqual(this.currentUser.title, "Test");
  });
});
