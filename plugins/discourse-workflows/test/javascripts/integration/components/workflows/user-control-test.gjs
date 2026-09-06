import { tracked } from "@glimmer/tracking";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import UserControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/user-control";

class TestField {
  @tracked value;

  constructor(value) {
    this.value = value;
  }

  set(newValue) {
    this.value = newValue;
  }
}

module("Integration | Component | Workflows | UserControl", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/u/search/users", () =>
      response(200, {
        users: [
          { username: "sam", name: "Sam" },
          { username: "alice", name: "Alice" },
        ],
      })
    );
  });

  test("stores one username by default", async function (assert) {
    this.field = new TestField("");

    await render(
      <template>
        <UserControl @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    const chooser = selectKit(".user-chooser");
    await chooser.expand();
    await chooser.fillInFilter("s");
    await chooser.selectRowByValue("sam");

    assert.strictEqual(this.field.value, "sam");
  });

  test("stores all selected usernames when configured as multiple", async function (assert) {
    this.field = new TestField([]);
    this.schema = { ui: { multiple: true } };

    await render(
      <template>
        <UserControl
          @field={{this.field}}
          @schema={{this.schema}}
          @supportsExpression={{false}}
        />
      </template>
    );

    const chooser = selectKit(".user-chooser");
    await chooser.expand();
    await chooser.fillInFilter("s");
    await chooser.selectRowByValue("sam");

    assert.deepEqual(this.field.value, ["sam"]);

    await chooser.fillInFilter("a");
    await chooser.selectRowByValue("alice");

    assert.deepEqual(this.field.value, ["sam", "alice"]);
  });
});
