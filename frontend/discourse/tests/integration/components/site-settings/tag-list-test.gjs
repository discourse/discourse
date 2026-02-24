import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TagList from "discourse/admin/components/site-settings/tag-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | site-settings/tag-list", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("selecting a tag updates the value with the tag name", async function (assert) {
    this.set("value", "");

    await render(<template><TagList @value={{this.value}} /></template>);

    await this.subject.expand();
    await this.subject.selectRowByName("monkey");

    assert.strictEqual(this.value, "monkey");
  });

  test("displays pre-selected tags from pipe-delimited value", async function (assert) {
    this.set("value", "foo|bar|baz");

    await render(<template><TagList @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().value(), "foo,bar,baz");
  });

  test("displays no tags when value is empty", async function (assert) {
    this.set("value", "");

    await render(<template><TagList @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().value(), null);
  });
});
