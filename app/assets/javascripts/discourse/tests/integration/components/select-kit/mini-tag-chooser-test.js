import { click, render, triggerKeyEvent } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { queryAll } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";

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

      assert.dom(".select-kit-error").hasText(
        i18n("select_kit.max_content_reached", {
          count: this.siteSettings.max_tags_per_topic,
        })
      );
    });

    test("disables search and shows limit when max_tags_per_topic is zero", async function (assert) {
      this.set("value", ["cat", "kit"]);
      this.siteSettings.max_tags_per_topic = 0;

      await render(hbs`<MiniTagChooser @value={{this.value}} />`);

      assert.strictEqual(this.subject.header().value(), "cat,kit");
      await this.subject.expand();

      assert.dom(".select-kit-error").hasText(
        i18n("select_kit.max_content_reached", {
          count: 0,
        })
      );
      await this.subject.fillInFilter("dawg");
      assert
        .dom(".select-kit-collection .select-kit-row")
        .doesNotExist("doesn’t show any options");
    });

    test("required_tag_group", async function (assert) {
      this.set("value", ["foo", "bar"]);

      await render(
        hbs`<MiniTagChooser @value={{this.value}} @options={{hash categoryId=1}} />`
      );

      assert.strictEqual(this.subject.header().value(), "foo,bar");

      await this.subject.expand();

      assert.dom("input[name=filter-input-search]").hasAttribute(
        "placeholder",
        i18n("tagging.choose_for_topic_required_group", {
          count: 1,
          name: "monkey group",
        })
      );

      await this.subject.selectRowByValue("monkey");

      assert
        .dom("input[name=filter-input-search]")
        .hasAttribute("placeholder", i18n("select_kit.filter_placeholder"));
    });

    test("creating a tag using invalid character", async function (assert) {
      await render(hbs`<MiniTagChooser @options={{hash allowAny=true}} />`);
      await this.subject.expand();
      await this.subject.fillInFilter("#");

      assert.dom(".select-kit-error").doesNotExist("doesn’t show any error");
      assert
        .dom(".select-kit-row[data-value='#']")
        .doesNotExist("doesn't allow to create this tag");

      await this.subject.fillInFilter("test");

      assert.strictEqual(this.subject.filter().value(), "#test");
      assert
        .dom(".select-kit-row[data-value='test']")
        .exists("filters out the invalid char from the suggested tag");
    });

    test("creating a tag over the length limit", async function (assert) {
      this.siteSettings.max_tag_length = 1;
      await render(hbs`<MiniTagChooser @options={{hash allowAny=true}} />`);
      await this.subject.expand();
      await this.subject.fillInFilter("foo");

      assert
        .dom(".select-kit-row[data-value='f']")
        .exists("forces the max length of the tag");
    });

    test("values in hiddenFromPreview will not display in preview", async function (assert) {
      this.set("value", ["foo", "bar"]);
      this.set("hiddenValues", ["foo"]);

      await render(
        hbs`<MiniTagChooser @options={{hash allowAny=true hiddenValues=this.hiddenValues}} @value={{this.value}} />`
      );
      assert.dom(".formatted-selection").hasText("bar");

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

module(
  "Integration | Component | select-kit/mini-tag-chooser useHeaderFilter=true",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.set("subject", selectKit());
    });

    test("displays tags and filter in header", async function (assert) {
      this.set("value", ["apple", "orange", "potato"]);

      await render(
        hbs`<MiniTagChooser @value={{this.value}} @options={{hash filterable=true useHeaderFilter=true}} />`
      );

      assert.strictEqual(this.subject.header().value(), "apple,orange,potato");

      assert.dom(".select-kit-header--filter").exists();
      assert.dom(".select-kit-header button[data-name='apple']").exists();
      assert.dom(".select-kit-header button[data-name='orange']").exists();
      assert.dom(".select-kit-header button[data-name='potato']").exists();

      const filterInput = ".select-kit-header .filter-input";
      await click(filterInput);

      await triggerKeyEvent(filterInput, "keydown", "ArrowDown");
      await triggerKeyEvent(filterInput, "keydown", "Enter");

      assert.dom(".select-kit-header button[data-name='monkey']").exists();

      await triggerKeyEvent(filterInput, "keydown", "Backspace");

      assert
        .dom(".select-kit-header button[data-name='monkey']")
        .doesNotExist();

      await this.subject.fillInFilter("foo");
      await triggerKeyEvent(filterInput, "keydown", "Backspace");

      assert.dom(".select-kit-header button[data-name='potato']").exists();
    });

    test("removing a tag does not display the dropdown", async function (assert) {
      this.set("value", ["apple", "orange", "potato"]);

      await render(
        hbs`<MiniTagChooser @value={{this.value}} @options={{hash filterable=true useHeaderFilter=true}} />`
      );

      assert.strictEqual(this.subject.header().value(), "apple,orange,potato");

      await click(".select-kit-header button[data-name='apple']");

      assert.dom(".select-kit-collection").doesNotExist();
      assert.dom(".select-kit-header button[data-name='apple']").doesNotExist();
      assert.strictEqual(this.subject.header().value(), "orange,potato");

      assert
        .dom(".select-kit-header .filter-input")
        .hasAttribute(
          "placeholder",
          "",
          "Placeholder is empty when there is a selection"
        );

      await click(".select-kit-header button[data-name='orange']");
      await click(".select-kit-header button[data-name='potato']");

      assert
        .dom(".select-kit-header .filter-input")
        .hasAttribute(
          "placeholder",
          "Search…",
          "Placeholder is back to default when there is no selection"
        );
    });
  }
);
