import { trackedObject } from "@ember/reactive/collections";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import UserOrGroupControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/user-or-group-control";

module(
  "Integration | Component | Workflows | UserOrGroupControl",
  function (hooks) {
    setupRenderingTest(hooks);

    test("with the new select controls, stores the picked group's name, and an empty string once cleared", async function (assert) {
      this.siteSettings.enable_new_select_controls = true;
      pretender.get("/u/search/users", (request) =>
        response(200, {
          users: [],
          groups:
            request.queryParams.include_groups === "true"
              ? [{ name: "support", full_name: "Support" }]
              : [],
        })
      );
      const field = trackedObject({
        value: "",
        set(newValue) {
          this.value = newValue;
        },
      });

      await render(
        <template>
          <UserOrGroupControl @field={{field}} @supportsExpression={{false}} />
        </template>
      );

      const select = dSelect(".d-select.email-group-user-chooser");
      await select.search("sup");
      await select.selectByName("support");
      assert.strictEqual(field.value, "support");

      await select.clear();
      assert.strictEqual(field.value, "");
    });
  }
);
