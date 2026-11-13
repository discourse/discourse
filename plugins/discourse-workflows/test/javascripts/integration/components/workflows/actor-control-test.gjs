import { trackedObject } from "@ember/reactive/collections";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ActorControl from "discourse/plugins/discourse-workflows/admin/components/workflows/configurators/actor-control";

function fieldFor(value) {
  return {
    value,
    set(newValue) {
      this.value = newValue;
    },
  };
}

module("Integration | Component | workflows actor control", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/u/search/users", () => response(200, { users: [] }));
  });

  test("defaults to the system kind without a user chooser", async function (assert) {
    this.field = fieldFor("system");

    await render(
      <template>
        <ActorControl @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    assert.dom(".workflows-actor-control__user").doesNotExist();
    assert.strictEqual(
      selectKit(".workflows-actor-control__kind").header().value(),
      "system"
    );
  });

  test("renders the anonymous kind without a user chooser", async function (assert) {
    this.field = fieldFor("anonymous");

    await render(
      <template>
        <ActorControl @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    assert.dom(".workflows-actor-control__user").doesNotExist();
    assert.strictEqual(
      selectKit(".workflows-actor-control__kind").header().value(),
      "anonymous"
    );
  });

  test("can exclude the anonymous kind", async function (assert) {
    this.field = fieldFor("system");
    this.schema = { control_options: { allow_anonymous: false } };

    await render(
      <template>
        <ActorControl
          @field={{this.field}}
          @schema={{this.schema}}
          @supportsExpression={{false}}
        />
      </template>
    );

    const kind = selectKit(".workflows-actor-control__kind");
    await kind.expand();

    assert.false(kind.rowByValue("anonymous").exists());
  });

  test("renders the user chooser for a specific username", async function (assert) {
    this.field = fieldFor("alice");

    await render(
      <template>
        <ActorControl @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    assert.dom(".workflows-actor-control__user").exists();
    assert.strictEqual(
      selectKit(".workflows-actor-control__kind").header().value(),
      "user"
    );
  });

  test("selecting the anonymous kind stores the anonymous sentinel", async function (assert) {
    this.field = fieldFor("system");

    await render(
      <template>
        <ActorControl @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    const kind = selectKit(".workflows-actor-control__kind");
    await kind.expand();
    await kind.selectRowByValue("anonymous");

    assert.strictEqual(this.field.value, "anonymous");
    assert.dom(".workflows-actor-control__user").doesNotExist();
  });

  test("switching to the specific-user kind reveals the user chooser", async function (assert) {
    this.field = fieldFor("system");

    await render(
      <template>
        <ActorControl @field={{this.field}} @supportsExpression={{false}} />
      </template>
    );

    const kind = selectKit(".workflows-actor-control__kind");
    await kind.expand();
    await kind.selectRowByValue("user");

    assert.dom(".workflows-actor-control__user").exists();
    assert.strictEqual(this.field.value, "");
  });

  test("with the new select controls, stores the picked username, and an empty string once cleared", async function (assert) {
    this.siteSettings.enable_new_select_controls = true;
    pretender.get("/u/search/users", (request) =>
      response(200, {
        users: [{ username: "bob", name: "Bob" }].filter((user) =>
          user.username.startsWith(request.queryParams.term)
        ),
      })
    );
    const field = trackedObject(fieldFor("alice"));

    await render(
      <template>
        <ActorControl @field={{field}} @supportsExpression={{false}} />
      </template>
    );

    const select = dSelect(".d-select.workflows-actor-control__user");
    assert.dom(select.element()).hasAttribute("data-value", "alice");

    await select.search("bo");
    await select.selectByName("bob");
    assert.strictEqual(field.value, "bob");

    await select.clear();
    assert.strictEqual(field.value, "");
  });
});
