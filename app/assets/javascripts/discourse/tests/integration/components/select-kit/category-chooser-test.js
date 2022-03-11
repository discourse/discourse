import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import I18n from "I18n";
import createStore from "discourse/tests/helpers/create-store";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule(
  "Integration | Component | select-kit/category-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("with value", {
      template: hbs`
        {{category-chooser
          value=value
        }}
      `,

      beforeEach() {
        this.set("value", 2);
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().value(), "2");
        assert.strictEqual(this.subject.header().label(), "feature");
      },
    });

    componentTest("with excludeCategoryId", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            excludeCategoryId=2
          )
        }}
      `,

      async test(assert) {
        await this.subject.expand();

        assert.notOk(this.subject.rowByValue(2).exists());
      },
    });

    componentTest("with scopedCategoryId", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            scopedCategoryId=2
          )
        }}
      `,

      async test(assert) {
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
      },
    });

    componentTest("with prioritizedCategoryId", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            prioritizedCategoryId=5
          )
        }}
      `,

      async test(assert) {
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
          22,
          "all categories are visible"
        );

        await this.subject.fillInFilter("bug");

        assert.strictEqual(
          this.subject.rowByIndex(0).name(),
          "bug",
          "search still finds categories"
        );
      },
    });

    componentTest("with allowUncategorized=null", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            allowUncategorized=null
          )
        }}
      `,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = false;
      },

      test(assert) {
        assert.strictEqual(this.subject.header().value(), null);
        assert.strictEqual(this.subject.header().label(), "category…");
      },
    });

    componentTest("with allowUncategorized=null rootNone=true", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            allowUncategorized=null
            none=true
          )
        }}
      `,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = false;
      },

      test(assert) {
        assert.strictEqual(this.subject.header().value(), null);
        assert.strictEqual(this.subject.header().label(), "(no category)");
      },
    });

    componentTest("with disallowed uncategorized, none", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            allowUncategorized=null
            none="test.root"
          )
        }}
      `,

      beforeEach() {
        I18n.translations[I18n.locale].js.test = { root: "root none label" };
        this.siteSettings.allow_uncategorized_topics = false;
      },

      test(assert) {
        assert.strictEqual(this.subject.header().value(), null);
        assert.strictEqual(this.subject.header().label(), "root none label");
      },
    });

    componentTest("with allowed uncategorized", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            allowUncategorized=true
          )
        }}
      `,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = true;
      },

      test(assert) {
        assert.strictEqual(this.subject.header().value(), null);
        assert.strictEqual(this.subject.header().label(), "uncategorized");
      },
    });

    componentTest("with allowed uncategorized and none=true", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            allowUncategorized=true
            none=true
          )
        }}
      `,

      beforeEach() {
        this.siteSettings.allow_uncategorized_topics = true;
      },

      test(assert) {
        assert.strictEqual(this.subject.header().value(), null);
        assert.strictEqual(this.subject.header().label(), "(no category)");
      },
    });

    componentTest("with allowed uncategorized and none", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash
            allowUncategorized=true
            none="test.root"
          )
        }}
      `,

      beforeEach() {
        I18n.translations[I18n.locale].js.test = { root: "root none label" };
        this.siteSettings.allow_uncategorized_topics = true;
      },

      test(assert) {
        assert.strictEqual(this.subject.header().value(), null);
        assert.strictEqual(this.subject.header().label(), "root none label");
      },
    });

    componentTest("filter is case insensitive", {
      template: hbs`
        {{category-chooser
          value=value
        }}
      `,

      async test(assert) {
        await this.subject.expand();
        await this.subject.fillInFilter("bug");

        assert.strictEqual(this.subject.rows().length, 1);
        assert.strictEqual(this.subject.rowByIndex(0).name(), "bug");

        await this.subject.emptyFilter();
        await this.subject.fillInFilter("Bug");

        assert.strictEqual(this.subject.rows().length, 1);
        assert.strictEqual(this.subject.rowByIndex(0).name(), "bug");
      },
    });

    componentTest("filter works with non english characters", {
      template: hbs`
        {{category-chooser
          value=value
        }}
      `,

      beforeEach() {
        const store = createStore();
        store.createRecord("category", {
          id: 1,
          name: "chữ Quốc ngữ",
        });
      },

      async test(assert) {
        await this.subject.expand();
        await this.subject.fillInFilter("gữ");

        assert.strictEqual(this.subject.rows().length, 1);
        assert.strictEqual(this.subject.rowByIndex(0).name(), "chữ Quốc ngữ");
      },
    });

    componentTest("decodes entities in row title", {
      template: hbs`
        {{category-chooser
          value=value
          options=(hash scopedCategoryId=1)
        }}
      `,

      beforeEach() {
        const store = createStore();
        store.createRecord("category", {
          id: 1,
          name: "cat-with-entities",
          description_text: "baz &quot;bar ‘foo’",
        });
      },

      async test(assert) {
        await this.subject.expand();

        assert.strictEqual(
          this.subject.rowByIndex(0).el()[0].querySelector(".category-desc")
            .innerText,
          'baz "bar ‘foo’'
        );
      },
    });
  }
);
