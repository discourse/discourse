import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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
});
