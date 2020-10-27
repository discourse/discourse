import { exists } from "discourse/tests/helpers/qunit-helpers";
import { moduleForComponent } from "ember-qunit";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import componentTest from "discourse/tests/helpers/component-test";
import { click } from "@ember/test-helpers";

moduleForComponent("select-kit/combo-box", {
  integration: true,
  beforeEach() {
    this.set("subject", selectKit());
  },
});

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
    },
    options || {}
  );
  ctx.setProperties(properties);
};

componentTest("options.clearable", {
  template: `
    {{combo-box
      value=value
      content=content
      onChange=onChange
      options=(hash clearable=clearable)
    }}
  `,

  beforeEach() {
    setDefaultState(this, {
      clearable: true,
      onChange: (value) => {
        this.set("value", value);
      },
    });
  },

  async test(assert) {
    const $header = this.subject.header();

    assert.ok(
      exists($header.el().find(".btn-clear")),
      "it shows the clear button"
    );
    assert.equal($header.value(), DEFAULT_VALUE);

    await click($header.el().find(".btn-clear"));

    assert.notOk(
      exists($header.el().find(".btn-clear")),
      "it hides the clear button"
    );
    assert.equal($header.value(), null);
  },
});

componentTest("options.{caretUpIcon,caretDownIcon}", {
  template: `
    {{combo-box
      value=value
      content=content
      options=(hash
        caretUpIcon=caretUpIcon
        caretDownIcon=caretDownIcon
      )
    }}
  `,

  beforeEach() {
    setDefaultState(this, {
      caretUpIcon: "pencil-alt",
      caretDownIcon: "trash-alt",
    });
  },

  async test(assert) {
    const $header = this.subject.header().el();

    assert.ok(
      exists($header.find(`.d-icon-${this.caretDownIcon}`)),
      "it uses the icon provided"
    );

    await this.subject.expand();

    assert.ok(
      exists($header.find(`.d-icon-${this.caretUpIcon}`)),
      "it uses the icon provided"
    );
  },
});
