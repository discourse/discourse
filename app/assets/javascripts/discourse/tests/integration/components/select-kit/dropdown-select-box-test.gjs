import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

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
      const self = this;

      setDefaultState(this);

      await render(
        <template>
          <DropdownSelectBox @value={{self.value}} @content={{self.content}} />
        </template>
      );

      await this.subject.expand();
      assert.true(this.subject.isExpanded());

      await this.subject.selectRowByValue(DEFAULT_VALUE);
      assert.false(
        this.subject.isExpanded(),
        "collapses the dropdown on select"
      );
    });

    test("options.showFullTitle=false", async function (assert) {
      const self = this;

      setDefaultState(this, {
        value: null,
        showFullTitle: false,
        none: "test_none",
      });

      await render(
        <template>
          <DropdownSelectBox
            @value={{self.value}}
            @content={{self.content}}
            @options={{hash
              icon="xmark"
              showFullTitle=self.showFullTitle
              none=self.none
            }}
          />
        </template>
      );

      assert
        .dom(".selected-name", this.subject.header().el())
        .doesNotExist("hides the text of the selected item");

      assert
        .dom(this.subject.header().el())
        .hasAttribute(
          "title",
          "[en.test_none]",
          "adds a title attribute to the button"
        );
    });

    test("options.showFullTitle=true", async function (assert) {
      const self = this;

      setDefaultState(this, { showFullTitle: true });

      await render(
        <template>
          <DropdownSelectBox
            @value={{self.value}}
            @content={{self.content}}
            @options={{hash showFullTitle=self.showFullTitle}}
          />
        </template>
      );

      assert
        .dom(".selected-name", this.subject.header().el())
        .exists("shows the text of the selected item");
    });
  }
);
