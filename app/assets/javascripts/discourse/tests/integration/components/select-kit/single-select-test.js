import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import I18n from "I18n";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
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
      nameProperty: "name",
      valueProperty: "id",
      onChange: (value) => {
        ctx.set("value", value);
      },
    },
    options || {}
  );
  ctx.setProperties(properties);
};

discourseModule(
  "Integration | Component | select-kit/single-select",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("content", {
      template: hbs`{{single-select content=content}}`,

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

    componentTest("value", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
      }}
    `,

      beforeEach() {
        setDefaultState(this);
      },

      test(assert) {
        assert.strictEqual(
          this.subject.header().value(this.content),
          "1",
          "it selects the correct content to display"
        );
      },
    });

    componentTest("options.filterable", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
        options=(hash
          filterable=filterable
        )
      }}
    `,

      beforeEach() {
        setDefaultState(this, { filterable: true });
      },

      async test(assert) {
        await this.subject.expand();
        assert.ok(this.subject.filter().exists(), "it shows the filter");

        const filter = this.subject.displayedContent()[1].name;
        await this.subject.fillInFilter(filter);
        assert.strictEqual(
          this.subject.displayedContent()[0].name,
          filter,
          "it filters the list"
        );
      },
    });

    componentTest("options.limitMatches", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
        options=(hash
          limitMatches=limitMatches
          filterable=filterable
        )
      }}
    `,

      beforeEach() {
        setDefaultState(this, { limitMatches: 1, filterable: true });
      },

      async test(assert) {
        await this.subject.expand();
        await this.subject.fillInFilter("ba");

        assert.strictEqual(
          this.subject.displayedContent().length,
          1,
          "it returns only 1 result"
        );
      },
    });

    componentTest("valueAttribute (deprecated)", {
      template: hbs`
      {{single-select
        value=value
        content=content
        valueAttribute="value"
      }}
    `,

      beforeEach() {
        this.set("value", "normal");

        const content = [
          { name: "Smallest", value: "smallest" },
          { name: "Smaller", value: "smaller" },
          { name: "Normal", value: "normal" },
          { name: "Larger", value: "larger" },
          { name: "Largest", value: "largest" },
        ];
        this.set("content", content);
      },

      async test(assert) {
        await this.subject.expand();

        assert.strictEqual(this.subject.selectedRow().value(), this.value);
      },
    });

    componentTest("none:string", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
        options=(hash
          none="test.none"
        )
      }}
    `,

      beforeEach() {
        I18n.translations[I18n.locale].js.test = { none: "(default)" };
        setDefaultState(this, { value: 1 });
      },

      async test(assert) {
        await this.subject.expand();

        const noneRow = this.subject.rowByIndex(0);
        assert.strictEqual(noneRow.value(), null);
        assert.strictEqual(noneRow.name(), I18n.t("test.none"));
      },
    });

    componentTest("none:object", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
        options=(hash
          none=none
        )
      }}
    `,

      beforeEach() {
        setDefaultState(this, { none: { value: null, name: "(default)" } });
      },

      async test(assert) {
        await this.subject.expand();

        const noneRow = this.subject.rowByIndex(0);
        assert.strictEqual(noneRow.value(), null);
        assert.strictEqual(noneRow.name(), "(default)");
      },
    });

    componentTest("content is a basic array", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
        options=(hash
          none="test.none"
        )
      }}
    `,

      beforeEach() {
        I18n.translations[I18n.locale].js.test = { none: "(default)" };
        setDefaultState(this, {
          nameProperty: null,
          valueProperty: null,
          value: "foo",
          content: ["foo", "bar", "baz"],
        });
      },

      async test(assert) {
        await this.subject.expand();

        const noneRow = this.subject.rowByIndex(0);
        assert.strictEqual(noneRow.value(), I18n.t("test.none"));
        assert.strictEqual(noneRow.name(), I18n.t("test.none"));
        assert.strictEqual(this.value, "foo");

        await this.subject.selectRowByIndex(0);

        assert.strictEqual(this.value, null);
      },
    });

    componentTest("selected value can be 0", {
      template: hbs`
      {{single-select
        value=value
        content=content
        nameProperty=nameProperty
        valueProperty=valueProperty
        onChange=onChange
      }}
    `,

      beforeEach() {
        setDefaultState(this, {
          value: 1,
          content: [
            { id: 0, name: "foo" },
            { id: 1, name: "bar" },
          ],
        });
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().value(), "1");

        await this.subject.expand();
        await this.subject.selectRowByValue(0);

        assert.strictEqual(this.subject.header().value(), "0");
      },
    });

    componentTest("prevents propagating click event on header", {
      template: hbs`
      {{#d-button icon='times' action=onClick}}
        {{single-select
          options=(hash preventsClickPropagation=true)
          value=value
          content=content
        }}
      {{/d-button}}
    `,

      beforeEach() {
        this.setProperties({
          onClick: () => this.set("value", "foo"),
          content: DEFAULT_CONTENT,
          value: DEFAULT_VALUE,
        });
      },

      async test(assert) {
        assert.strictEqual(this.value, DEFAULT_VALUE);
        await this.subject.expand();
        assert.strictEqual(this.value, DEFAULT_VALUE);
      },
    });

    componentTest("labelProperty", {
      template: hbs`
      {{single-select
        labelProperty="foo"
        value=value
        content=content
      }}
    `,

      beforeEach() {
        this.setProperties({
          content: [{ id: 1, name: "john", foo: "JACKSON" }],
          value: 1,
        });
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().label(), "JACKSON");

        await this.subject.expand();

        const row = this.subject.rowByValue(1);

        assert.strictEqual(row.label(), "JACKSON");
      },
    });

    componentTest("titleProperty", {
      template: hbs`
      {{single-select
        titleProperty="foo"
        value=value
        content=content
      }}
    `,

      beforeEach() {
        this.setProperties({
          content: [{ id: 1, name: "john", foo: "JACKSON" }],
          value: 1,
        });
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().title(), "JACKSON");

        await this.subject.expand();

        const row = this.subject.rowByValue(1);

        assert.strictEqual(row.title(), "JACKSON");
      },
    });

    componentTest("langProperty", {
      template: hbs`{{single-select langProperty="foo" value=value content=content}}`,

      beforeEach() {
        this.setProperties({
          content: [{ id: 1, name: "john", foo: "be" }],
          value: null,
        });
      },

      async test(assert) {
        assert.strictEqual(
          this.subject.header().el().querySelector(".selected-name").lang,
          ""
        );

        await this.subject.expand();

        const row = this.subject.rowByValue(1);
        assert.strictEqual(row.el().lang, "be");

        await this.subject.selectRowByValue(1);

        assert.strictEqual(
          this.subject.header().el().querySelector(".selected-name").lang,
          "be"
        );
      },
    });

    componentTest("name", {
      template: hbs`{{single-select value=value content=content}}`,

      beforeEach() {
        this.setProperties({
          content: [{ id: 1, name: "john" }],
          value: null,
        });
      },

      async test(assert) {
        assert.strictEqual(
          this.subject.header().el().getAttribute("name"),
          I18n.t("select_kit.select_to_filter")
        );

        await this.subject.expand();
        await this.subject.selectRowByValue(1);

        assert.strictEqual(
          this.subject.header().el().getAttribute("name"),
          I18n.t("select_kit.filter_by", {
            name: this.content.firstObject.name,
          })
        );
      },
    });
  }
);
