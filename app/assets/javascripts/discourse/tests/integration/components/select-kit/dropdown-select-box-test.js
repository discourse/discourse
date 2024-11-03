import { render } from "@ember/test-helpers";
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

const setDefaultState = (ctx, options) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: DEFAULT_VALUE,
      onChange: (value) => {
        this.set("value", value);
      },
    },
    options || {}
  );
  ctx.setProperties(properties);
};

module(
  "Integration | Component | select-kit/dropdown-select-box",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("selection behavior", async function (assert) {
      setDefaultState(this);

      await render(hbs`
        <DropdownSelectBox
          @value={{this.value}}
          @content={{this.content}}
        />
      `);

      await this.subject.expand();
      assert.ok(this.subject.isExpanded());

      await this.subject.selectRowByValue(DEFAULT_VALUE);
      assert.false(
        this.subject.isExpanded(),
        "collapses the dropdown on select"
      );
    });

    test("options.showFullTitle=false", async function (assert) {
      setDefaultState(this, {
        value: null,
        showFullTitle: false,
        none: "test_none",
      });

      await render(hbs`
        <DropdownSelectBox
          @value={{this.value}}
          @content={{this.content}}
          @options={{hash
            icon="xmark"
            showFullTitle=this.showFullTitle
            none=this.none
          }}
        />
      `);

      assert
        .dom(".selected-name", this.subject.header().el())
        .doesNotExist("hides the text of the selected item");

      assert.strictEqual(
        this.subject.header().el().getAttribute("title"),
        "[en.test_none]",
        "it adds a title attribute to the button"
      );
    });

    test("options.showFullTitle=true", async function (assert) {
      setDefaultState(this, { showFullTitle: true });

      await render(hbs`
        <DropdownSelectBox
          @value={{this.value}}
          @content={{this.content}}
          @options={{hash
            showFullTitle=this.showFullTitle
          }}
        />
      `);

      assert.ok(
        this.subject.header().el().querySelector(".selected-name"),
        "it shows the text of the selected item"
      );
    });
  }
);
