import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import TagList from "discourse/admin/components/site-settings/tag-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

class State {
  @tracked value = "";
}

module("Integration | Component | SiteSettings | TagList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("selecting a tag reports the tag name", async function (assert) {
    const state = new State();
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      state.value = value;
    };

    await render(
      <template>
        <TagList @changeValueCallback={{changeValue}} @value={{state.value}} />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByName("monkey");

    assert.deepEqual(changes, ["monkey"]);
  });

  test("displays pre-selected tags from pipe-delimited value", async function (assert) {
    this.set("value", "foo|bar|baz");

    await render(<template><TagList @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().value(), "foo,bar,baz");
  });

  test("follows a value set by the caller", async function (assert) {
    const state = new State();
    state.value = "foo";

    await render(<template><TagList @value={{state.value}} /></template>);

    state.value = "foo|bar";
    await settled();

    assert.strictEqual(this.subject.header().value(), "foo,bar");
  });

  test("displays no tags when value is empty", async function (assert) {
    this.set("value", "");

    await render(<template><TagList @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().value(), null);
  });
});
