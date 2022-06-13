import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import hbs from "htmlbars-inline-precompile";
import selectKit from "discourse/tests/helpers/select-kit-helper";

discourseModule(
  "Integration | Component | select-kit/mini-tag-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    componentTest("displays tags", {
      template: hbs`{{mini-tag-chooser value=value}}`,

      beforeEach() {
        this.set("value", ["foo", "bar"]);
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().value(), "foo,bar");
      },
    });

    componentTest("create a tag", {
      template: hbs`{{mini-tag-chooser value=value}}`,

      beforeEach() {
        this.set("value", ["foo", "bar"]);
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().value(), "foo,bar");

        await this.subject.expand();
        await this.subject.fillInFilter("mon");
        assert.strictEqual(
          queryAll(".select-kit-row").text().trim(),
          "monkey x1\ngazelle x2"
        );
        await this.subject.fillInFilter("key");
        assert.strictEqual(
          queryAll(".select-kit-row").text().trim(),
          "monkey x1\ngazelle x2"
        );
        await this.subject.selectRowByValue("monkey");

        assert.strictEqual(this.subject.header().value(), "foo,bar,monkey");
      },
    });

    componentTest("max_tags_per_topic", {
      template: hbs`{{mini-tag-chooser value=value}}`,

      beforeEach() {
        this.set("value", ["foo", "bar"]);
        this.siteSettings.max_tags_per_topic = 2;
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().value(), "foo,bar");

        await this.subject.expand();
        await this.subject.fillInFilter("baz");
        await this.subject.selectRowByValue("monkey");

        const error = queryAll(".select-kit-error").text();
        assert.strictEqual(
          error,
          I18n.t("select_kit.max_content_reached", {
            count: this.siteSettings.max_tags_per_topic,
          })
        );
      },
    });

    componentTest("required_tag_group", {
      template: hbs`{{mini-tag-chooser value=value options=(hash categoryId=1)}}`,

      beforeEach() {
        this.set("value", ["foo", "bar"]);
      },

      async test(assert) {
        assert.strictEqual(this.subject.header().value(), "foo,bar");

        await this.subject.expand();

        assert.strictEqual(
          query("input[name=filter-input-search]").placeholder,
          I18n.t("tagging.choose_for_topic_required_group", {
            count: 1,
            name: "monkey group",
          })
        );

        await this.subject.selectRowByValue("monkey");

        assert.strictEqual(
          query("input[name=filter-input-search]").placeholder,
          I18n.t("select_kit.filter_placeholder")
        );
      },
    });
  }
);
