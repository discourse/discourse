import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { paste, query } from "discourse/tests/helpers/qunit-helpers";

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

module(
  "Integration | Component | select-kit/email-group-user-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("pasting", async function (assert) {
      setDefaultState(this);

      await render(hbs`
      <EmailGroupUserChooser
        @value={{this.value}}
        @content={{this.content}}
        @options={{hash maximum=2}}
      />
    `);

      await this.subject.expand();
      await paste(query(".filter-input"), "foo,bar");

      assert.equal(this.subject.header().value(), "foo,bar");
    });
  }
);
