import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { query, queryAll } from "discourse/tests/helpers/qunit-helpers";
import I18n from "I18n";
import { hbs } from "ember-cli-htmlbars";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module(
  "Integration | Component | select-kit/mini-tag-chooser",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("displays tags", async function (assert) {
      this.set("value", ["foo", "bar"]);

      await render(hbs`<MiniTagChooser @value={{this.value}} />`);

      assert.strictEqual(this.subject.header().value(), "foo,bar");
    });

    test("create a tag", async function (assert) {
      this.set("value", ["foo", "bar"]);

      await render(hbs`<MiniTagChooser @value={{this.value}} />`);

      assert.strictEqual(this.subject.header().value(), "foo,bar");

      await this.subject.expand();
      await this.subject.fillInFilter("mon");
      assert.deepEqual(
        [...queryAll(".select-kit-row")].map((el) => el.textContent.trim()),
        ["monkey x1", "gazelle x2"]
      );
      await this.subject.fillInFilter("key");
      assert.deepEqual(
        [...queryAll(".select-kit-row")].map((el) => el.textContent.trim()),
        ["monkey x1", "gazelle x2"]
      );
      await this.subject.selectRowByValue("monkey");

      assert.strictEqual(this.subject.header().value(), "foo,bar,monkey");
    });

    test("max_tags_per_topic", async function (assert) {
      this.set("value", ["foo", "bar"]);
      this.siteSettings.max_tags_per_topic = 2;

      await render(hbs`<MiniTagChooser @value={{this.value}} />`);

      assert.strictEqual(this.subject.header().value(), "foo,bar");

      await this.subject.expand();
      await this.subject.fillInFilter("baz");
      await this.subject.selectRowByValue("monkey");

      const error = query(".select-kit-error").innerText;
      assert.strictEqual(
        error,
        I18n.t("select_kit.max_content_reached", {
          count: this.siteSettings.max_tags_per_topic,
        })
      );
    });

    test("required_tag_group", async function (assert) {
      this.set("value", ["foo", "bar"]);

      await render(
        hbs`<MiniTagChooser @value={{this.value}} @options={{hash categoryId=1}} />`
      );

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
    });
  }
);
