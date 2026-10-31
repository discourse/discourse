import { tracked } from "@glimmer/tracking";
import { trackedObject } from "@ember/reactive/collections";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import UserControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/user-control";

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
    this.field = tracked("");

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
    this.field = tracked([]);
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

  module("with the new select controls", function (nestedHooks) {
    nestedHooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
      pretender.get("/u/search/users", (request) =>
        response(200, {
          users: [
            { username: "sam", name: "Sam" },
            { username: "alice", name: "Alice" },
          ].filter((user) =>
            user.username.startsWith(request.queryParams.term)
          ),
        })
      );
    });

    function fieldFor(value) {
      return trackedObject({
        value,
        set(newValue) {
          this.value = newValue;
        },
      });
    }

    test("stores one username, and an empty string once cleared", async function (assert) {
      const field = fieldFor("");

      await render(
        <template>
          <UserControl @field={{field}} @supportsExpression={{false}} />
        </template>
      );

      const select = dSelect(".d-select.user-chooser");
      await select.search("s");
      await select.selectByName("sam");
      assert.strictEqual(field.value, "sam");

      await select.clear();
      assert.strictEqual(field.value, "");
    });

    test("stores every picked username when configured as multiple", async function (assert) {
      const field = fieldFor([]);
      const schema = { ui: { multiple: true } };

      await render(
        <template>
          <UserControl
            @field={{field}}
            @schema={{schema}}
            @supportsExpression={{false}}
          />
        </template>
      );

      const select = dSelect(".d-select.user-chooser");
      await select.search("s");
      await select.selectByName("sam");
      await select.search("a");
      await select.selectByName("alice");

      assert.deepEqual(field.value, ["sam", "alice"]);
    });
  });
});
