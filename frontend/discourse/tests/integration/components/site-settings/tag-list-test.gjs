import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import TagList from "discourse/admin/components/site-settings/tag-list";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dSelect from "discourse/tests/helpers/d-select-helper";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | SiteSettings | TagList", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("selecting a tag reports the tag name", async function (assert) {
    const settingValue = tracked("");
    const changes = [];
    const changeValue = (value) => {
      changes.push(value);
      settingValue.value = value;
    };

    await render(
      <template>
        <TagList
          @changeValueCallback={{changeValue}}
          @value={{settingValue.value}}
        />
      </template>
    );

    await this.subject.expand();
    await this.subject.selectRowByName("monkey");

    assert.deepEqual(changes, ["monkey"]);
  });

  test("displays pre-selected tags from pipe-delimited value", async function (assert) {
    this.set("value", "foo|bar|baz");

    await render(<template><TagList @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().value(), "foo,bar,baz");
  });

  test("follows a value set by the caller", async function (assert) {
    const settingValue = tracked("foo");

    await render(
      <template><TagList @value={{settingValue.value}} /></template>
    );

    settingValue.value = "foo|bar";
    await settled();

    assert.strictEqual(this.subject.header().value(), "foo,bar");
  });

  test("displays no tags when value is empty", async function (assert) {
    this.set("value", "");

    await render(<template><TagList @value={{this.value}} /></template>);

    assert.strictEqual(this.subject.header().value(), null);
  });
});

module(
  "Integration | Component | SiteSettings | TagList (new select controls)",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("selecting a tag reports the tag name", async function (assert) {
      const settingValue = tracked("");
      const changes = [];
      const changeValue = (value) => {
        changes.push(value);
        settingValue.value = value;
      };

      await render(
        <template>
          <TagList
            @changeValueCallback={{changeValue}}
            @value={{settingValue.value}}
          />
        </template>
      );

      assert.dom(".d-select").exists("the new control renders");
      await dSelect(".d-select").selectByName("monkey");

      assert.deepEqual(changes, ["monkey"]);
    });

    test("pre-selected names show as chips and keep their names", async function (assert) {
      const settingValue = tracked("foo|bar");
      const changes = [];
      const changeValue = (value) => {
        changes.push(value);
        settingValue.value = value;
      };

      await render(
        <template>
          <TagList
            @changeValueCallback={{changeValue}}
            @value={{settingValue.value}}
          />
        </template>
      );

      assert.dom(".d-select").hasAttribute("data-name", "foo,bar");
      await dSelect(".d-select").selectByName("monkey");
      assert.deepEqual(changes, ["foo|bar|monkey"], "held names stay names");
    });

    test("the control follows @disabled", async function (assert) {
      await render(
        <template><TagList @disabled={{true}} @value="foo" /></template>
      );

      assert.dom(".d-select__trigger").hasClass("--disabled");
    });
  }
);
