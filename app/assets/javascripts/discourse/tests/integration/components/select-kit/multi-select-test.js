import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { paste, query } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const DEFAULT_CONTENT = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" },
];

const setDefaultState = (ctx, options) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: null,
    },
    options || {}
  );
  ctx.setProperties(properties);
};

module("Integration | Component | select-kit/multi-select", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("content", async function (assert) {
    setDefaultState(this);

    await render(hbs`
      <MultiSelect
        @value={{this.value}}
        @content={{this.content}}
      />
    `);

    await this.subject.expand();

    const content = this.subject.displayedContent();
    assert.strictEqual(content.length, 3, "it shows rows");
    assert.strictEqual(
      content[0].name,
      this.content.firstObject.name,
      "it has the correct name"
    );
    assert.strictEqual(
      content[0].id,
      this.content.firstObject.id.toString(),
      "it has the correct value"
    );
    assert.strictEqual(
      this.subject.header().value(),
      null,
      "it doesn't set a value from the content"
    );
  });

  test("maximum=1", async function (assert) {
    setDefaultState(this);

    await render(hbs`
      <MultiSelect
        @value={{this.value}}
        @content={{this.content}}
        @options={{hash maximum=1}}
      />
    `);

    await this.subject.expand();
    await this.subject.selectRowByValue(1);

    assert.false(this.subject.isExpanded(), "closes the dropdown");

    await this.subject.expand();
    await this.subject.deselectItemByValue(1);

    assert.ok(
      this.subject.isExpanded(),
      "it doesn’t close the dropdown when no selection has been made"
    );
  });

  test("maximum=2", async function (assert) {
    setDefaultState(this);

    await render(hbs`
      <MultiSelect
        @value={{this.value}}
        @content={{this.content}}
        @options={{hash maximum=2}}
      />
    `);

    await this.subject.expand();
    await this.subject.selectRowByValue(1);

    assert.ok(this.subject.isExpanded(), "it doesn’t close the dropdown");
  });

  test("pasting", async function (assert) {
    setDefaultState(this);

    await render(hbs`
      <MultiSelect
        @value={{this.value}}
        @content={{this.content}}
        @options={{hash maximum=2}}
      />
    `);

    await this.subject.expand();
    await paste(query(".filter-input"), "foo|bar");

    assert.strictEqual(this.subject.header().value(), "1,2");
  });

  test("no value property with no content", async function (assert) {
    setDefaultState(this);

    await render(hbs`
      <MultiSelect @valueProperty={{null}} />
    `);
    await this.subject.expand();

    assert
      .dom(".selected-content")
      .doesNotExist("it doesn’t render an empty content div");
  });
});
