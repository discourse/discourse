import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import AutomationField from "discourse/plugins/automation/admin/components/automation-field";
import AutomationFabricators from "discourse/plugins/automation/admin/lib/fabricators";

module("Integration | Component | da-users-field", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.automation = new AutomationFabricators(getOwner(this)).automation();

    pretender.get("/u/search/users", () =>
      response({
        users: [
          {
            username: "sam",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
          {
            username: "joffrey",
            avatar_template:
              "https://avatars.discourse.org/v3/letter/t/41988e/{size}.png",
          },
        ],
      })
    );
  });

  test("sets values", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "users",
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("sam");
    await selectKit().selectRowByValue("sam");
    await selectKit().fillInFilter("joffrey");
    await selectKit().selectRowByValue("joffrey");

    assert.deepEqual(this.field.metadata.value, ["sam", "joffrey"]);
  });

  test("allows emails", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "users",
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("j.jaffeux@example.com");
    await selectKit().selectRowByValue("j.jaffeux@example.com");

    assert.deepEqual(this.field.metadata.value, ["j.jaffeux@example.com"]);
  });

  test("empty", async function (assert) {
    const self = this;

    this.field = new AutomationFabricators(getOwner(this)).field({
      component: "users",
    });

    await render(
      <template>
        <AutomationField
          @automation={{self.automation}}
          @field={{self.field}}
        />
      </template>
    );

    await selectKit().expand();
    await selectKit().fillInFilter("sam");
    await selectKit().selectRowByValue("sam");

    assert.deepEqual(this.field.metadata.value, ["sam"]);

    await selectKit().deselectItemByValue("sam");

    assert.strictEqual(this.field.metadata.value, undefined);
  });
});
