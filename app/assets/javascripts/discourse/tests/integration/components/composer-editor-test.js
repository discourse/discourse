import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | ComposerEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("warns about users that will not see a mention", async function (assert) {
    assert.expect(1);

    this.set("model", {});
    this.set("noop", () => {});
    this.set("expectation", (warnings) => {
      assert.deepEqual(warnings, [
        { name: "user-no", reason: "a reason" },
        { name: "user-nope", reason: "a reason" },
      ]);
    });

    pretender.get("/u/is_local_username", () => {
      return response({
        cannot_see: {
          "user-no": "a reason",
          "user-nope": "a reason",
        },
        mentionable_groups: [],
        valid: ["user-ok", "user-no", "user-nope"],
        valid_groups: [],
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
