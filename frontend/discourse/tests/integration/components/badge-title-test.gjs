import EmberObject from "@ember/object";
import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BadgeTitle from "discourse/components/badge-title";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | BadgeTitle", function (hooks) {
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

  module("with the new select controls", function (nestedHooks) {
    let saved;

    /** The badges a user can take as a title, after the page's placeholder for none. */
    function titleBadges() {
      return [
        EmberObject.create({ id: 0, badge: { name: "(none)" } }),
        EmberObject.create({
          id: 42,
          badge_id: 102,
          badge: { id: 102, name: "Test", icon: "bolt" },
        }),
        EmberObject.create({
          id: 43,
          badge_id: 103,
          badge: {
            id: 103,
            name: "Pictured",
            image_url: "/images/pictured.png",
          },
        }),
      ];
    }

    nestedHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      saved = [];
      pretender.put("/u/eviltrout/preferences/badge_title", (request) => {
        saved.push(
          new URLSearchParams(request.requestBody).get("user_badge_id")
        );
        return response({});
      });
    });

    test("lists the title badges once, with their glyphs, and saves the picked one", async function (assert) {
      const selectableUserBadges = titleBadges();

      await render(
        <template>
          <BadgeTitle @selectableUserBadges={{selectableUserBadges}} />
        </template>
      );
      await new DSelect().open();

      assert.deepEqual(
        findAll("[role='option']:not(.--none)").map((row) => row.dataset.value),
        ["102", "103"],
        "the badges are listed by badge, without the page's none placeholder"
      );
      assert
        .dom("[role='option'].--none")
        .exists({ count: 1 }, "None is offered once");
      assert
        .dom("[role='option'][data-value='103'] img")
        .hasAttribute("src", "/images/pictured.png");

      await new DSelect().select(103);
      await click(".badge-title .btn-primary");

      assert.deepEqual(saved, ["43"], "the user badge behind it is saved");
      assert.strictEqual(this.currentUser.title, "Pictured");
    });

    test("starts on the current title, and None clears it", async function (assert) {
      this.currentUser.set("title", "Test");
      const selectableUserBadges = titleBadges();

      await render(
        <template>
          <BadgeTitle @selectableUserBadges={{selectableUserBadges}} />
        </template>
      );

      assert.dom(".d-select__trigger").includesText("Test");

      await new DSelect().open();
      await click("[role='option'].--none");
      await click(".badge-title .btn-primary");

      assert.deepEqual(saved, ["0"]);
      assert.strictEqual(this.currentUser.title, "");
    });
  });
});
