import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | ComposerEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("warns about users that will not see a mention", async function (assert) {
    assert.expect(2);

    this.set("model", {});
    this.set("noop", () => {});
    this.set("expectation", (warning) => {
      if (warning.name === "user-no") {
        assert.deepEqual(warning, { name: "user-no", reason: "a reason" });
      } else if (warning.name === "user-nope") {
        assert.deepEqual(warning, { name: "user-nope", reason: "a reason" });
      }
    });

    pretender.get("/composer/mentions", () => {
      return response({
        users: ["user-ok", "user-no", "user-nope"],
        user_reasons: {
          "user-no": "a reason",
          "user-nope": "a reason",
        },
        groups: {},
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });

    await render(hbs`
      <ComposerEditor
        @composer={{this.model}}
        @afterRefresh={{this.noop}}
        @cannotSeeMention={{this.expectation}}
      />
    `);

    await fillIn("textarea", "@user-no @user-ok @user-nope");
  });
});
