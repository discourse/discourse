import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule, exists } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
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

discourseModule(
  "Integration | Component | select-kit/dropdown-select-box",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("selection behavior", {
      template: hbs`
      {{dropdown-select-box
        value=value
        content=content
      }}
    `,

      beforeEach() {
        setDefaultState(this);
      },

      async test(assert) {
        await this.subject.expand();
        assert.ok(this.subject.isExpanded());

        await this.subject.selectRowByValue(DEFAULT_VALUE);
        assert.notOk(
          this.subject.isExpanded(),
          "it collapses the dropdown on select"
        );
      },
    });

    componentTest("options.showFullTitle=false", {
      template: hbs`
      {{dropdown-select-box
        value=value
        content=content
        options=(hash
          icon="times"
          showFullTitle=showFullTitle
          none=none
        )
      }}
    `,

      beforeEach() {
        setDefaultState(this, {
          value: null,
          showFullTitle: false,
          none: "test_none",
        });
      },

      async test(assert) {
        assert.ok(
          !exists(this.subject.header().el().find(".selected-name")),
          "it hides the text of the selected item"
        );

        assert.strictEqual(
          this.subject.header().el().attr("title"),
          "[en.test_none]",
          "it adds a title attribute to the button"
        );
      },
    });

    componentTest("options.showFullTitle=true", {
      template: hbs`
      {{dropdown-select-box
        value=value
        content=content
        options=(hash
          showFullTitle=showFullTitle
        )
      }}
    `,

      beforeEach() {
        setDefaultState(this, { showFullTitle: true });
      },

      async test(assert) {
        assert.ok(
          exists(this.subject.header().el().find(".selected-name")),
          "it shows the text of the selected item"
        );
      },
    });
  }
);
