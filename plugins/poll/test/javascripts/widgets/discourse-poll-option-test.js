import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

module(
  "Integration | Component | Widget | discourse-poll-option",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`
      <MountWidget
        @widget="discourse-poll-option"
        @args={{hash
          option=this.option
          isMultiple=this.isMultiple
          vote=this.vote
        }}
      />
    `;

    test("single, not selected", async function (assert) {
      this.set("option", { id: "opt-id" });
      this.set("vote", []);

      await render(template);

      assert.strictEqual(count("li .d-icon-far-circle:nth-of-type(1)"), 1);
    });

    test("single, selected", async function (assert) {
      this.set("option", { id: "opt-id" });
      this.set("vote", ["opt-id"]);

      await render(template);

      assert.strictEqual(count("li .d-icon-circle:nth-of-type(1)"), 1);
    });

    test("multi, not selected", async function (assert) {
      this.setProperties({
        option: { id: "opt-id" },
        isMultiple: true,
        vote: [],
      });

      await render(template);

      assert.strictEqual(count("li .d-icon-far-square:nth-of-type(1)"), 1);
    });

    test("multi, selected", async function (assert) {
      this.setProperties({
        option: { id: "opt-id" },
        isMultiple: true,
        vote: ["opt-id"],
      });

      await render(template);

      assert.strictEqual(
        count("li .d-icon-far-check-square:nth-of-type(1)"),
        1
      );
    });
  }
);
