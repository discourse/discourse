import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

const DEFAULT_CONTENT = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" },
];

const DEFAULT_VALUE = 1;

const setDefaultState = (ctx, options = {}) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: DEFAULT_VALUE,
    },
    options
  );
  ctx.setProperties(properties);
};

module("Integration | Component | select-kit/combo-box", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("options.clearable", async function (assert) {
    setDefaultState(this, {
      clearable: true,
      onChange: (value) => {
        this.set("value", value);
      },
    });

    await render(hbs`
      <ComboBox
        @value={{this.value}}
        @content={{this.content}}
        @onChange={{this.onChange}}
        @options={{hash clearable=this.clearable}}
      />
    `);

    const header = this.subject.header();

    assert.ok(
      header.el().querySelector(".btn-clear"),
      "it shows the clear button"
    );
    assert.strictEqual(header.value(), DEFAULT_VALUE.toString());

    await click(header.el().querySelector(".btn-clear"));

    assert
      .dom(".btn-clear", header.el())
      .doesNotExist("hides the clear button");
    assert.strictEqual(header.value(), null);
  });

  test("options.{caretUpIcon,caretDownIcon}", async function (assert) {
    setDefaultState(this, {
      caretUpIcon: "pencil",
      caretDownIcon: "trash-can",
    });

    await render(hbs`
      <ComboBox
        @value={{this.value}}
        @content={{this.content}}
        @options={{hash
          caretUpIcon=this.caretUpIcon
          caretDownIcon=this.caretDownIcon
        }}
      />
    `);

    const header = this.subject.header().el();

    assert.ok(
      header.querySelector(`.d-icon-${this.caretDownIcon}`),
      "it uses the icon provided"
    );

    await this.subject.expand();

    assert.ok(
      header.querySelector(`.d-icon-${this.caretUpIcon}`),
      "it uses the icon provided"
    );
  });
});
