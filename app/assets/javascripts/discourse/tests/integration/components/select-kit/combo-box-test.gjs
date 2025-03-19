import { hash } from "@ember/helper";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import ComboBox from "select-kit/components/combo-box";

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
    const self = this;

    setDefaultState(this, {
      clearable: true,
      onChange: (value) => {
        this.set("value", value);
      },
    });

    await render(
      <template>
        <ComboBox
          @value={{self.value}}
          @content={{self.content}}
          @onChange={{self.onChange}}
          @options={{hash clearable=self.clearable}}
        />
      </template>
    );

    const header = this.subject.header();

    assert.dom(".btn-clear", header.el()).exists("shows the clear button");
    assert.strictEqual(header.value(), DEFAULT_VALUE.toString());

    await click(header.el().querySelector(".btn-clear"));

    assert
      .dom(".btn-clear", header.el())
      .doesNotExist("hides the clear button");
    assert.strictEqual(header.value(), null);
  });

  test("options.{caretUpIcon,caretDownIcon}", async function (assert) {
    const self = this;

    setDefaultState(this, {
      caretUpIcon: "pencil",
      caretDownIcon: "trash-can",
    });

    await render(
      <template>
        <ComboBox
          @value={{self.value}}
          @content={{self.content}}
          @options={{hash
            caretUpIcon=self.caretUpIcon
            caretDownIcon=self.caretDownIcon
          }}
        />
      </template>
    );

    const header = this.subject.header().el();

    assert
      .dom(`.d-icon-${this.caretDownIcon}`, header)
      .exists("uses the icon provided");

    await this.subject.expand();

    assert
      .dom(`.d-icon-${this.caretUpIcon}`, header)
      .exists("uses the icon provided");
  });
});
