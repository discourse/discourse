import { hash } from "@ember/helper";
import { find, render, tab } from "@ember/test-helpers";
import { module, test } from "qunit";
import DButton from "discourse/components/d-button";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n, { i18n } from "discourse-i18n";
import SingleSelect from "select-kit/components/single-select";

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

module("Integration | Component | select-kit/single-select", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("content", async function (assert) {
    const self = this;

    setDefaultState(this);

    await render(
      <template><SingleSelect @content={{self.content}} /></template>
    );

    await this.subject.expand();

    const content = this.subject.displayedContent();
    assert.strictEqual(content.length, 3, "shows rows");
    assert.strictEqual(
      content[0].name,
      this.content.firstObject.name,
      "has the correct name"
    );
    assert.strictEqual(
      content[0].id,
      this.content.firstObject.id.toString(),
      "has the correct value"
    );
    assert.strictEqual(
      this.subject.header().value(),
      null,
      "doesn't set a value from the content"
    );
  });

  test("accessibility", async function (assert) {
    const self = this;

    setDefaultState(this);

    await render(
      <template><SingleSelect @content={{self.content}} /></template>
    );

    await this.subject.expand();

    const content = this.subject.displayedContent();
    assert.strictEqual(content.length, 3, "shows rows");

    assert.dom(".select-kit-header").isFocused("focuses the header first");

    await tab();

    assert
      .dom(".select-kit-row:first-child")
      .isFocused("focuses the first row next");

    await tab();

    assert
      .dom(".select-kit-row:nth-child(2)")
      .isFocused("tab moves focus to 2nd row");

    await tab();

    assert
      .dom(".select-kit-row:nth-child(3)")
      .isFocused("tab moves focus to 3rd row");

    await tab();

    assert.false(
      this.subject.isExpanded(),
      "when there are no more rows, Tab collapses the dropdown"
    );

    await this.subject.expand();

    assert.true(this.subject.isExpanded(), "dropdown is expanded again");

    await tab({ backwards: true });

    assert.false(this.subject.isExpanded(), "Shift+Tab collapses the dropdown");
  });

  test("value", async function (assert) {
    const self = this;

    setDefaultState(this);

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
        />
      </template>
    );

    assert.strictEqual(
      this.subject.header().value(this.content),
      "1",
      "selects the correct content to display"
    );
  });

  test("options.filterable", async function (assert) {
    const self = this;

    setDefaultState(this, { filterable: true });

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
          @options={{hash filterable=self.filterable}}
        />
      </template>
    );

    await this.subject.expand();
    assert.true(this.subject.filter().exists(), "shows the filter");

    const filter = this.subject.displayedContent()[1].name;
    await this.subject.fillInFilter(filter);
    assert.strictEqual(
      this.subject.displayedContent()[0].name,
      filter,
      "filters the list"
    );
  });

  test("options.limitMatches", async function (assert) {
    const self = this;

    setDefaultState(this, { limitMatches: 1, filterable: true });

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
          @options={{hash
            limitMatches=self.limitMatches
            filterable=self.filterable
          }}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.fillInFilter("ba");

    assert.strictEqual(
      this.subject.displayedContent().length,
      1,
      "returns only 1 result"
    );
  });

  test("valueAttribute (deprecated)", async function (assert) {
    const self = this;

    this.set("value", "normal");

    const content = [
      { name: "Smallest", value: "smallest" },
      { name: "Smaller", value: "smaller" },
      { name: "Normal", value: "normal" },
      { name: "Larger", value: "larger" },
      { name: "Largest", value: "largest" },
    ];
    this.set("content", content);

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @valueAttribute="value"
        />
      </template>
    );

    await this.subject.expand();

    assert.strictEqual(this.subject.selectedRow().value(), this.value);
  });

  test("none:string", async function (assert) {
    const self = this;

    I18n.translations[I18n.locale].js.test = { none: "(default)" };
    setDefaultState(this, { value: 1 });

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
          @options={{hash none="test.none"}}
        />
      </template>
    );

    await this.subject.expand();

    const noneRow = this.subject.rowByIndex(0);
    assert.strictEqual(noneRow.value(), null);
    assert.strictEqual(noneRow.name(), i18n("test.none"));
  });

  test("none:object", async function (assert) {
    const self = this;

    setDefaultState(this, { none: { value: null, name: "(default)" } });

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
          @options={{hash none=self.none}}
        />
      </template>
    );

    await this.subject.expand();

    const noneRow = this.subject.rowByIndex(0);
    assert.strictEqual(noneRow.value(), null);
    assert.strictEqual(noneRow.name(), "(default)");
  });

  test("content is a basic array", async function (assert) {
    const self = this;

    I18n.translations[I18n.locale].js.test = { none: "(default)" };
    setDefaultState(this, {
      nameProperty: null,
      valueProperty: null,
      value: "foo",
      content: ["foo", "bar", "baz"],
    });

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
          @options={{hash none="test.none"}}
        />
      </template>
    );

    await this.subject.expand();

    const noneRow = this.subject.rowByIndex(0);
    assert.strictEqual(noneRow.value(), i18n("test.none"));
    assert.strictEqual(noneRow.name(), i18n("test.none"));
    assert.strictEqual(this.value, "foo");

    await this.subject.selectRowByIndex(0);

    assert.strictEqual(this.value, null);
  });

  test("selected value can be 0", async function (assert) {
    const self = this;

    setDefaultState(this, {
      value: 1,
      content: [
        { id: 0, name: "foo" },
        { id: 1, name: "bar" },
      ],
    });

    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
        />
      </template>
    );

    assert.strictEqual(this.subject.header().value(), "1");

    await this.subject.expand();
    await this.subject.selectRowByValue(0);

    assert.strictEqual(this.subject.header().value(), "0");
  });

  test("prevents propagating click event on header", async function (assert) {
    const self = this;

    this.setProperties({
      onClick: () => this.set("value", "foo"),
      content: DEFAULT_CONTENT,
      value: DEFAULT_VALUE,
    });

    await render(
      <template>
        <DButton @icon="xmark" @action={{self.onClick}}>
          <SingleSelect
            @value={{self.value}}
            @content={{self.content}}
            @options={{hash preventsClickPropagation=true}}
          />
        </DButton>
      </template>
    );

    assert.strictEqual(this.value, DEFAULT_VALUE);
    await this.subject.expand();
    assert.strictEqual(this.value, DEFAULT_VALUE);
  });

  test("labelProperty", async function (assert) {
    const self = this;

    this.setProperties({
      content: [{ id: 1, name: "john", foo: "JACKSON" }],
      value: 1,
    });

    await render(
      <template>
        <SingleSelect
          @labelProperty="foo"
          @value={{self.value}}
          @content={{self.content}}
        />
      </template>
    );

    assert.strictEqual(this.subject.header().label(), "JACKSON");

    await this.subject.expand();

    const row = this.subject.rowByValue(1);

    assert.strictEqual(row.label(), "JACKSON");
  });

  test("titleProperty", async function (assert) {
    const self = this;

    this.setProperties({
      content: [{ id: 1, name: "john", foo: "JACKSON" }],
      value: 1,
    });

    await render(
      <template>
        <SingleSelect
          @titleProperty="foo"
          @value={{self.value}}
          @content={{self.content}}
        />
      </template>
    );

    assert.strictEqual(this.subject.header().title(), "JACKSON");

    await this.subject.expand();

    const row = this.subject.rowByValue(1);

    assert.strictEqual(row.title(), "JACKSON");
  });

  test("langProperty", async function (assert) {
    const self = this;

    this.setProperties({
      content: [{ id: 1, name: "john", foo: "be" }],
      value: null,
    });

    await render(
      <template>
        <SingleSelect
          @langProperty="foo"
          @value={{self.value}}
          @content={{self.content}}
        />
      </template>
    );

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
  });

  test("name", async function (assert) {
    const self = this;

    this.setProperties({
      content: [{ id: 1, name: "john" }],
      value: null,
    });

    await render(
      <template>
        <SingleSelect @value={{self.value}} @content={{self.content}} />
      </template>
    );

    assert
      .dom(this.subject.header().el())
      .hasAttribute("name", i18n("select_kit.select_to_filter"));

    await this.subject.expand();
    await this.subject.selectRowByValue(1);

    assert.dom(this.subject.header().el()).hasAttribute(
      "name",
      i18n("select_kit.filter_by", {
        name: this.content.firstObject.name,
      })
    );
  });

  test("row index", async function (assert) {
    const self = this;

    this.setProperties({
      content: [
        { id: 1, name: "john" },
        { id: 2, name: "jane" },
      ],
      value: null,
    });

    await render(
      <template>
        <SingleSelect @value={{self.value}} @content={{self.content}} />
      </template>
    );
    await this.subject.expand();

    assert.dom('.select-kit-row[data-index="0"][data-value="1"]').exists();
    assert.dom('.select-kit-row[data-index="1"][data-value="2"]').exists();
  });

  test("options.verticalOffset", async function (assert) {
    const self = this;

    setDefaultState(this, { verticalOffset: -50 });
    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @nameProperty={{self.nameProperty}}
          @valueProperty={{self.valueProperty}}
          @onChange={{self.onChange}}
          @options={{hash verticalOffset=self.verticalOffset}}
        />
      </template>
    );
    await this.subject.expand();
    const header = find(".select-kit-header").getBoundingClientRect();
    const body = find(".select-kit-body").getBoundingClientRect();

    assert.true(header.bottom > body.top, "correctly offsets the body");
  });

  test("options.expandedOnInsert", async function (assert) {
    const self = this;

    setDefaultState(this);
    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @options={{hash expandedOnInsert=true}}
        />
      </template>
    );

    assert.dom(".single-select.is-expanded").exists();
  });

  test("options.formName", async function (assert) {
    const self = this;

    setDefaultState(this);
    await render(
      <template>
        <SingleSelect
          @value={{self.value}}
          @content={{self.content}}
          @options={{hash formName="foo"}}
        />
      </template>
    );

    assert
      .dom('input[name="foo"]')
      .hasAttribute("type", "hidden")
      .hasAttribute("value", "1");
  });
});
