import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
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

discourseModule(
  "Integration | Component | select-kit/multi-select",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("content", {
      template: hbs`
      {{multi-select
        value=value
        content=content
      }}
    `,

      beforeEach() {
        setDefaultState(this);
      },

      async test(assert) {
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
      },
    });
  }
);
