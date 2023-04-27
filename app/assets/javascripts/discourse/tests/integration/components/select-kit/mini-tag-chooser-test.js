import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render, settled } from "@ember/test-helpers";
import { exists, query, queryAll } from "discourse/tests/helpers/qunit-helpers";
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
        ["monkey x1", "gazelle x2", "dog x3", "cat x4"]
      );
      await this.subject.fillInFilter("key");
      assert.deepEqual(
        [...queryAll(".select-kit-row")].map((el) => el.textContent.trim()),
        ["monkey x1", "gazelle x2", "dog x3", "cat x4"]
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
      await settled();

      assert.strictEqual(
        query(".select-kit-error").innerText,
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
      await settled();

      assert.strictEqual(
        query("input[name=filter-input-search]").placeholder,
        I18n.t("select_kit.filter_placeholder")
      );
    });

    test("creating a tag using invalid character", async function (assert) {
      await render(hbs`<MiniTagChooser @options={{hash allowAny=true}} />`);
      await this.subject.expand();
      await this.subject.fillInFilter("#");

      assert.notOk(exists(".select-kit-error"), "it doesn’t show any error");
      assert.notOk(
        exists(".select-kit-row[data-value='#']"),
        "it doesn’t allow to create this tag"
      );

      await this.subject.fillInFilter("test");

      assert.equal(this.subject.filter().value(), "#test");
      assert.ok(
        exists(".select-kit-row[data-value='test']"),
        "it filters out the invalid char from the suggested tag"
      );
    });

    test("creating a tag over the length limit", async function (assert) {
      this.siteSettings.max_tag_length = 1;
      await render(hbs`<MiniTagChooser @options={{hash allowAny=true}} />`);
      await this.subject.expand();
      await this.subject.fillInFilter("foo");

      assert.ok(
        exists(".select-kit-row[data-value='f']"),
        "it forces the max length of the tag"
      );
    });

    test("values in hiddenFromPreview will not display in preview", async function (assert) {
      this.set("value", ["foo", "bar"]);
      this.set("hiddenValues", ["foo"]);

      await render(
        hbs`<MiniTagChooser @options={{hash allowAny=true hiddenValues=this.hiddenValues}} @value={{this.value}} />`
      );
      assert.strictEqual(
        query(".formatted-selection").textContent.trim(),
        "bar"
      );

      await this.subject.expand();
      assert.deepEqual(
        [...queryAll(".selected-content .selected-choice")].map((el) =>
          el.textContent.trim()
        ),
        ["bar"]
      );
    });
  }
);
