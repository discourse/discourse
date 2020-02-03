import componentTest from "helpers/component-test";
import { testSelectKitModule } from "./select-kit-test-helper";

testSelectKitModule("single-select");

function template(options = []) {
  return `
    {{single-select
      value=value
      content=content
      nameProperty=nameProperty
      valueProperty=valueProperty
      onChange=onChange
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

const DEFAULT_VALUE = 1;

const setDefaultState = (ctx, options) => {
  const properties = Object.assign(
    {
      content: DEFAULT_CONTENT,
      value: DEFAULT_VALUE,
      nameProperty: "name",
      valueProperty: "id",
      onChange: value => {
        ctx.set("value", value);
      }
    },
    options || {}
  );
  ctx.setProperties(properties);
};

componentTest("content", {
  template: "{{single-select content=content}}",

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

componentTest("value", {
  template: template(),

  beforeEach() {
    setDefaultState(this);
  },

  test(assert) {
    assert.equal(
      this.subject.header().value(this.content),
      1,
      "it selects the correct content to display"
    );
  }
});

componentTest("options.filterable", {
  template: template(["filterable=filterable"]),

  beforeEach() {
    setDefaultState(this, { filterable: true });
  },

  async test(assert) {
    await this.subject.expand();
    assert.ok(this.subject.filter().exists(), "it shows the filter");

    const filter = this.subject.displayedContent()[1].name;
    await this.subject.fillInFilter(filter);
    assert.equal(
      this.subject.displayedContent()[0].name,
      filter,
      "it filters the list"
    );
  }
});

componentTest("options.limitMatches", {
  template: template(["limitMatches=limitMatches", "filterable=filterable"]),

  beforeEach() {
    setDefaultState(this, { limitMatches: 1, filterable: true });
  },

  async test(assert) {
    await this.subject.expand();
    await this.subject.fillInFilter("ba");

    assert.equal(
      this.subject.displayedContent().length,
      1,
      "it returns only 1 result"
    );
  }
});

componentTest("valueAttribute (deprecated)", {
  template: `
    {{single-select
      value=value
      content=content
      valueAttribute="value"
    }}
  `,

  beforeEach() {
    this.set("value", "normal");

    const content = [
      { name: "Smaller", value: "smaller" },
      { name: "Normal", value: "normal" },
      { name: "Larger", value: "larger" },
      { name: "Largest", value: "largest" }
    ];
    this.set("content", content);
  },

  async test(assert) {
    await this.subject.expand();

    assert.equal(this.subject.selectedRow().value(), this.value);
  }
});

componentTest("none:string", {
  template: template(['none="test.none"']),

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "(default)" };
    setDefaultState(this, { value: 1 });
  },

  async test(assert) {
    await this.subject.expand();

    const noneRow = this.subject.rowByIndex(0);
    assert.equal(noneRow.value(), null);
    assert.equal(noneRow.name(), I18n.t("test.none"));
  }
});

componentTest("none:object", {
  template: template(["none=none"]),

  beforeEach() {
    setDefaultState(this, { none: { value: null, name: "(default)" } });
  },

  async test(assert) {
    await this.subject.expand();

    const noneRow = this.subject.rowByIndex(0);
    assert.equal(noneRow.value(), null);
    assert.equal(noneRow.name(), "(default)");
  }
});

componentTest("content is a basic array", {
  template: template(['none="test.none"']),

  beforeEach() {
    I18n.translations[I18n.locale].js.test = { none: "(default)" };
    setDefaultState(this, {
      nameProperty: null,
      valueProperty: null,
      value: "foo",
      content: ["foo", "bar", "baz"]
    });
  },

  async test(assert) {
    await this.subject.expand();

    const noneRow = this.subject.rowByIndex(0);
    assert.equal(noneRow.value(), I18n.t("test.none"));
    assert.equal(noneRow.name(), I18n.t("test.none"));
    assert.equal(this.value, "foo");

    await this.subject.selectRowByIndex(0);

    assert.equal(this.value, null);
  }
});
