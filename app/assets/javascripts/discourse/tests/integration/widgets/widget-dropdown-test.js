import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { click } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

const DEFAULT_CONTENT = {
  content: [
    { id: 1, label: "foo" },
    { id: 2, translatedLabel: "FooBar" },
    "separator",
    { id: 3, translatedLabel: "With icon", icon: "times" },
    { id: 4, html: "<b>baz</b>" },
    { id: 5, translatedLabel: "Disabled", disabled: true },
  ],
  label: "foo",
};

async function clickRowById(id) {
  await click(`#my-dropdown .widget-dropdown-item.item-${id}`);
}

function rowById(id) {
  return query(`#my-dropdown .widget-dropdown-item.item-${id}`);
}

async function toggle() {
  await click("#my-dropdown .widget-dropdown-header");
}

function headerLabel() {
  return queryAll(
    "#my-dropdown .widget-dropdown-header .label"
  )[0].innerText.trim();
}

function header() {
  return query("#my-dropdown .widget-dropdown-header");
}

function body() {
  return query("#my-dropdown .widget-dropdown-body");
}

const TEMPLATE = hbs`
  {{mount-widget
    widget="widget-dropdown"
    args=(hash
      id="my-dropdown"
      icon=icon
      label=label
      class=class
      translatedLabel=translatedLabel
      content=content
      options=options
    )
}}`;

discourseModule(
  "Integration | Component | Widget | widget-dropdown",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("dropdown id", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      test(assert) {
        assert.ok(exists("#my-dropdown"));
      },
    });

    componentTest("label", {
      template: TEMPLATE,

      _translations: I18n.translations,

      beforeEach() {
        I18n.translations = { en: { js: { foo: "FooBaz" } } };
        this.setProperties(DEFAULT_CONTENT);
      },

      afterEach() {
        I18n.translations = this._translations;
      },

      test(assert) {
        assert.equal(headerLabel(), "FooBaz");
      },
    });

    componentTest("translatedLabel", {
      template: TEMPLATE,

      _translations: I18n.translations,

      beforeEach() {
        I18n.translations = { en: { js: { foo: "FooBaz" } } };
        this.setProperties(DEFAULT_CONTENT);
        this.set("translatedLabel", "BazFoo");
      },

      afterEach() {
        I18n.translations = this._translations;
      },

      test(assert) {
        assert.equal(headerLabel(), this.translatedLabel);
      },
    });

    componentTest("content", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        await toggle();
        assert.equal(rowById(1).dataset.id, 1, "it creates rows");
        assert.equal(rowById(2).dataset.id, 2, "it creates rows");
        assert.equal(rowById(3).dataset.id, 3, "it creates rows");
      },
    });

    componentTest("onChange action", {
      template: hbs`
      <div id="test"></div>
      {{mount-widget
        widget="widget-dropdown"
        args=(hash
          id="my-dropdown"
          label=label
          content=content
          onChange=onChange
        )
      }}
    `,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);

        this.set("onChange", (item) => (query("#test").innerText = item.id));
      },

      async test(assert) {
        await toggle();
        await clickRowById(2);
        assert.equal(
          queryAll("#test").text(),
          2,
          "it calls the onChange actions"
        );
      },
    });

    componentTest("can be opened and closed", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        assert.ok(exists("#my-dropdown.closed"));
        assert.ok(!exists("#my-dropdown .widget-dropdown-body"));
        await toggle();
        assert.equal(rowById(2).innerText.trim(), "FooBar");
        assert.ok(exists("#my-dropdown.opened"));
        assert.ok(exists("#my-dropdown .widget-dropdown-body"));
        await toggle();
        assert.ok(exists("#my-dropdown.closed"));
        assert.ok(!exists("#my-dropdown .widget-dropdown-body"));
      },
    });

    componentTest("icon", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
        this.set("icon", "times");
      },

      test(assert) {
        assert.ok(exists(header().querySelector(".d-icon-times")));
      },
    });

    componentTest("class", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
        this.set("class", "activated");
      },

      test(assert) {
        assert.ok(exists("#my-dropdown.activated"));
      },
    });

    componentTest("content with translatedLabel", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        await toggle();
        assert.equal(rowById(2).innerText.trim(), "FooBar");
      },
    });

    componentTest("content with label", {
      template: TEMPLATE,

      _translations: I18n.translations,

      beforeEach() {
        I18n.translations = { en: { js: { foo: "FooBaz" } } };
        this.setProperties(DEFAULT_CONTENT);
      },

      afterEach() {
        I18n.translations = this._translations;
      },

      async test(assert) {
        await toggle();
        assert.equal(rowById(1).innerText.trim(), "FooBaz");
      },
    });

    componentTest("content with icon", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        await toggle();
        assert.ok(exists(rowById(3).querySelector(".d-icon-times")));
      },
    });

    componentTest("content with html", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        await toggle();
        assert.equal(rowById(4).innerHTML.trim(), "<span><b>baz</b></span>");
      },
    });

    componentTest("separator", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        await toggle();
        assert.ok(
          queryAll(
            "#my-dropdown .widget-dropdown-item:nth-child(3)"
          )[0].classList.contains("separator")
        );
      },
    });

    componentTest("hides widget if no content", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties({ content: null, label: "foo" });
      },

      test(assert) {
        assert.notOk(exists("#my-dropdown .widget-dropdown-header"));
        assert.notOk(exists("#my-dropdown .widget-dropdown-body"));
      },
    });

    componentTest("headerClass option", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
        this.set("options", { headerClass: "btn-small and-text" });
      },

      test(assert) {
        assert.ok(header().classList.contains("widget-dropdown-header"));
        assert.ok(header().classList.contains("btn-small"));
        assert.ok(header().classList.contains("and-text"));
      },
    });

    componentTest("bodyClass option", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
        this.set("options", { bodyClass: "gigantic and-yet-small" });
      },

      async test(assert) {
        await toggle();
        assert.ok(body().classList.contains("widget-dropdown-body"));
        assert.ok(body().classList.contains("gigantic"));
        assert.ok(body().classList.contains("and-yet-small"));
      },
    });

    componentTest("caret option", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
        this.set("options", { caret: true });
      },

      test(assert) {
        assert.ok(
          exists("#my-dropdown .widget-dropdown-header .d-icon-caret-down")
        );
      },
    });

    componentTest("disabled widget", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
        this.set("options", { disabled: true });
      },

      test(assert) {
        assert.ok(exists("#my-dropdown.disabled"));
      },

      async test(assert) {
        await toggle();
        assert.equal(rowById(1), undefined, "it does not display options");
      },
    });

    componentTest("disabled item", {
      template: TEMPLATE,

      beforeEach() {
        this.setProperties(DEFAULT_CONTENT);
      },

      async test(assert) {
        await toggle();
        assert.ok(exists(".widget-dropdown-item.item-5.disabled"));
      },
    });
  }
);
