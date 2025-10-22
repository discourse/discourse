import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import I18n from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";

module(
  "Integration | Component | select-kit/category-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("with value", async function (assert) {
      const self = this;
      this.set("value", 2);

      await render(
        <template><CategoryChooser @value={{self.value}} /></template>
      );

      assert.strictEqual(this.subject.header().value(), "2");
      assert.strictEqual(this.subject.header().label(), "feature");
    });

    test("with excludeCategoryId", async function (assert) {
      const self = this;
      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash excludeCategoryId=2}}
          />
        </template>
      );

      await this.subject.expand();

      assert.false(this.subject.rowByValue(2).exists());
    });

    test("with scopedCategoryId", async function (assert) {
      const self = this;
      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash scopedCategoryId=2}}
          />
        </template>
      );

      await this.subject.expand();

      assert.strictEqual(this.subject.rowByIndex(0).title(), "feature");
      assert.strictEqual(this.subject.rowByIndex(0).value(), "2");
      assert.strictEqual(this.subject.rowByIndex(1).title(), "spec");
      assert.strictEqual(this.subject.rowByIndex(1).value(), "26");
      assert.strictEqual(
        this.subject.rows().length,
        2,
        "default content is scoped"
      );

      await this.subject.fillInFilter("bug");

      assert.strictEqual(
        this.subject.rowByIndex(0).name(),
        "bug",
        "search finds outside of scope"
      );
    });

    test("with prioritizedCategoryId", async function (assert) {
      const self = this;
      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash prioritizedCategoryId=5}}
          />
        </template>
      );

      await this.subject.expand();

      // The prioritized category
      assert.strictEqual(this.subject.rowByIndex(0).value(), "5");
      // The prioritized category's child
      assert.strictEqual(this.subject.rowByIndex(1).value(), "22");
      // Other categories in the default order
      assert.strictEqual(this.subject.rowByIndex(2).value(), "6");
      assert.strictEqual(this.subject.rowByIndex(3).value(), "21");
      assert.strictEqual(this.subject.rowByIndex(4).value(), "1");

      assert.strictEqual(
        this.subject.rows().length,
        25,
        "all categories are visible"
      );

      await this.subject.fillInFilter("bug");

      assert.strictEqual(
        this.subject.rowByIndex(0).name(),
        "bug",
        "search still finds categories"
      );
    });

    test("with allowUncategorized=null", async function (assert) {
      const self = this;
      this.siteSettings.allow_uncategorized_topics = false;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=null}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "category…");
    });

    test("with allowUncategorized=null and defaultComposerCategory present", async function (assert) {
      const self = this;
      this.siteSettings.allow_uncategorized_topics = false;
      this.siteSettings.default_composer_category = 4;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=null}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "");
    });

    test("with allowUncategorized=null and defaultComposerCategory present, but not set", async function (assert) {
      const self = this;
      this.siteSettings.allow_uncategorized_topics = false;
      this.siteSettings.default_composer_category = -1;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=null}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "category…");
    });

    test("with allowUncategorized=null none=true", async function (assert) {
      const self = this;
      this.siteSettings.allow_uncategorized_topics = false;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=null none=true}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "(no category)");
    });

    test("with disallowed uncategorized, none", async function (assert) {
      const self = this;
      I18n.translations[I18n.locale].js.test = { root: "root none label" };
      this.siteSettings.allow_uncategorized_topics = false;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=null none="test.root"}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "root none label");
    });

    test("with allowed uncategorized", async function (assert) {
      const self = this;
      this.siteSettings.allow_uncategorized_topics = true;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=true}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "uncategorized");
    });

    test("with allowed uncategorized and none=true", async function (assert) {
      const self = this;
      this.siteSettings.allow_uncategorized_topics = true;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=true none=true}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "(no category)");
    });

    test("with allowed uncategorized and none", async function (assert) {
      const self = this;
      I18n.translations[I18n.locale].js.test = { root: "root none label" };
      this.siteSettings.allow_uncategorized_topics = true;

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash allowUncategorized=true none="test.root"}}
          />
        </template>
      );

      assert.strictEqual(this.subject.header().value(), null);
      assert.strictEqual(this.subject.header().label(), "root none label");
    });

    test("filter is case insensitive", async function (assert) {
      const self = this;
      await render(
        <template><CategoryChooser @value={{self.value}} /></template>
      );

      await this.subject.expand();
      await this.subject.fillInFilter("bug");

      assert.strictEqual(this.subject.rows().length, 1);
      assert.strictEqual(this.subject.rowByIndex(0).name(), "bug");

      await this.subject.emptyFilter();
      await this.subject.fillInFilter("Bug");

      assert.strictEqual(this.subject.rows().length, 1);
      assert.strictEqual(this.subject.rowByIndex(0).name(), "bug");
    });

    test("filter works with non english characters", async function (assert) {
      const self = this;
      const store = getOwner(this).lookup("service:store");
      store.createRecord("category", {
        id: 1,
        name: "chữ Quốc ngữ",
      });

      await render(
        <template><CategoryChooser @value={{self.value}} /></template>
      );

      await this.subject.expand();
      await this.subject.fillInFilter("gữ");

      assert.strictEqual(this.subject.rows().length, 1);
      assert.strictEqual(this.subject.rowByIndex(0).name(), "chữ Quốc ngữ");
    });

    test("decodes entities in row title", async function (assert) {
      const self = this;
      const store = getOwner(this).lookup("service:store");
      store.createRecord("category", {
        id: 1,
        name: "cat-with-entities",
        description_text: "baz &quot;bar ‘foo’",
      });

      await render(
        <template>
          <CategoryChooser
            @value={{self.value}}
            @options={{hash scopedCategoryId=1}}
          />
        </template>
      );

      await this.subject.expand();

      assert
        .dom(".category-desc", this.subject.rowByIndex(0).el())
        .hasText('baz "bar ‘foo’');
    });
  }
);
