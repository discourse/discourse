import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import TimezoneControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/timezone-control";

const NONE_KEY = "discourse_workflows.time_window.timezone_none";

module(
  "Integration | Component | Workflows | TimezoneControl",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("time zone control: stores the picked zone, or nothing to fall back to the default", async function (assert) {
      this.field = tracked("");
      this.schema = { control_options: { none: NONE_KEY } };

      await render(
        <template>
          <TimezoneControl
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{false}}
          />
        </template>
      );
      const select = dSelect(".timezone-input");
      await select.open();

      assert
        .dom(".d-select__panel [role='option']")
        .hasText("Workflow default", "the schema's fallback comes first");

      await select.search("lisbon");
      await select.select("Europe/Lisbon");

      assert.strictEqual(this.field.value, "Europe/Lisbon");

      await select.open();
      await select.selectByName("Workflow default");

      assert.strictEqual(this.field.value, null, "back to the default");
    });

    test("time zone control: a required zone offers no fallback", async function (assert) {
      this.field = tracked("Europe/Lisbon");
      this.schema = { required: true, control_options: { none: NONE_KEY } };

      await render(
        <template>
          <TimezoneControl
            @field={{this.field}}
            @schema={{this.schema}}
            @supportsExpression={{false}}
          />
        </template>
      );
      await dSelect(".timezone-input").open();

      assert.dom(".d-select__panel").doesNotIncludeText("Workflow default");
    });
  }
);
