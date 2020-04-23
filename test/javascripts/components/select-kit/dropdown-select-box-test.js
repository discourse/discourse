import selectKit from "helpers/select-kit-helper";
import componentTest from "helpers/component-test";

moduleForComponent("select-kit/dropdown-select-box", {
  integration: true,
  beforeEach() {
    this.set("subject", selectKit());
  }
});

const DEFAULT_CONTENT = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" }
];

const DEFAULT_VALUE = 1;

const setDefaultState = (ctx, options) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: DEFAULT_VALUE,
      onChange: value => {
        this.set("value", value);
      }
    },
    options || {}
  );
  ctx.setProperties(properties);
};

componentTest("selection behavior", {
  template: `
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
  }
});

componentTest("options.showFullTitle=false", {
  template: `
    {{dropdown-select-box
      value=value
      content=content
      options=(hash
        showFullTitle=showFullTitle
      )
    }}
  `,

  beforeEach() {
    setDefaultState(this, { showFullTitle: false });
  },

  async test(assert) {
    assert.ok(
      !exists(
        this.subject
          .header()
          .el()
          .find(".selected-name .body")
      ),
      "it hides the text of the selected item"
    );
  }
});

componentTest("options.showFullTitle=true", {
  template: `
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
      exists(
        this.subject
          .header()
          .el()
          .find(".selected-name")
      ),
      "it shows the text of the selected item"
    );
  }
});
