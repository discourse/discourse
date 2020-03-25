import componentTest from "helpers/component-test";
import { testSelectKitModule } from "./select-kit-test-helper";

testSelectKitModule("multi-select");

function template(options = []) {
  return `
    {{multi-select
      value=value
      content=content
      options=(hash
        ${options.join("\n")}
      )
    }}
  `;
}

const DEFAULT_CONTENT = [
  { id: 1, name: "foo" },
  { id: 2, name: "bar" },
  { id: 3, name: "baz" }
];

const setDefaultState = (ctx, options) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: null
    },
    options || {}
  );
  ctx.setProperties(properties);
};

componentTest("content", {
  template: template(),

  beforeEach() {
    setDefaultState(this);
  },

  async test(assert) {
    await this.subject.expand();

    const content = this.subject.displayedContent();
    assert.equal(content.length, 3, "it shows rows");
    assert.equal(
      content[0].name,
      this.content.firstObject.name,
      "it has the correct name"
    );
    assert.equal(
      content[0].id,
      this.content.firstObject.id,
      "it has the correct value"
    );
    assert.equal(
      this.subject.header().value(),
      null,
      "it doesn't set a value from the content"
    );
  }
});
