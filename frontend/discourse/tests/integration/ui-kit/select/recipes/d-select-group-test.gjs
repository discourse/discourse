import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { click, find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectGroup from "discourse/ui-kit/select/recipes/groups/d-select-group";
import { i18n } from "discourse-i18n";

const SITE_GROUPS = [
  { id: 0, name: "everyone", automatic: true },
  { id: 1, name: "admins", full_name: "Admins", automatic: true },
  { id: 10, name: "support", full_name: "Support crew", automatic: false },
  { id: 11, name: "design", full_name: "design", automatic: false },
  { id: 12, name: "sales", full_name: null, automatic: false },
];

/** The values of the listed options, in order. */
function optionValues() {
  return findAll("[role='option']").map((row) => row.dataset.value);
}

/** The option whose text includes `text`. */
function optionNamed(text) {
  return findAll("[role='option']").find((row) =>
    row.textContent.includes(text)
  );
}

module(
  "Integration | ui-kit | select | recipes | DSelectGroup",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.owner.lookup("service:site").groups = SITE_GROUPS;
    });

    test("lists the site's groups, a different full name as the description", async function (assert) {
      await render(<template><DSelectGroup /></template>);
      await new DSelect().open();

      assert.deepEqual(optionValues(), ["0", "1", "10", "11", "12"]);
      assert
        .dom(".d-select__option-description", optionNamed("support"))
        .hasText("Support crew");
      assert
        .dom(".d-select__option-description", optionNamed("design"))
        .doesNotExist("a full name that repeats the name isn't shown");
      assert
        .dom(".d-group-option .d-icon")
        .doesNotExist("a list of only groups has no group icon");
    });

    test("leaves automatic, everyone, excluded and unlisted groups out when asked", async function (assert) {
      const state = new (class {
        @tracked automatic;
        @tracked everyone;
        @tracked exclude;
        @tracked only;
      })();

      await render(
        <template>
          <DSelectGroup
            @automatic={{state.automatic}}
            @everyone={{state.everyone}}
            @exclude={{state.exclude}}
            @only={{state.only}}
          />
        </template>
      );
      const select = new DSelect();
      await select.open();

      state.everyone = false;
      await settled();
      assert.deepEqual(optionValues(), ["1", "10", "11", "12"]);

      state.automatic = false;
      await settled();
      assert.deepEqual(optionValues(), ["10", "11", "12"]);

      state.exclude = [11];
      await settled();
      assert.deepEqual(optionValues(), ["10", "12"]);

      state.only = [10, 11];
      await settled();
      assert.deepEqual(optionValues(), ["10"]);
    });

    test("filters by name as you type", async function (assert) {
      await render(<template><DSelectGroup /></template>);
      const select = new DSelect();
      await select.open();
      await select.search("sup");

      assert.deepEqual(optionValues(), ["10"]);
    });

    test("ids in, ids out, in single and multiple mode", async function (assert) {
      const onChange = sinon.spy();
      const state = new (class {
        @tracked value = "10";
        @tracked multiple = false;
      })();
      const change = (value) => {
        onChange(value);
        state.value = value;
      };

      await render(
        <template>
          <DSelectGroup
            @clearable={{true}}
            @multiple={{state.multiple}}
            @onChange={{change}}
            @value={{state.value}}
          />
        </template>
      );
      assert
        .dom(".d-select__trigger")
        .includesText("support", "a numeric string selects its group");

      const select = new DSelect();
      await select.open();
      await click(optionNamed("sales"));
      assert.strictEqual(onChange.lastCall.args[0], 12);

      await select.clear();
      assert.strictEqual(onChange.lastCall.args[0], null);

      state.multiple = true;
      state.value = [10];
      await settled();
      await select.open();
      await click(optionNamed("sales"));

      assert.deepEqual(onChange.lastCall.args[0], [10, 12]);
    });

    test("holds and emits names with @emit set to names", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelectGroup
            @emit="names"
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array "support"}}
          />
        </template>
      );
      assert.dom(".d-select__chip").includesText("support");

      const select = new DSelect();
      await select.open();
      await click(optionNamed("sales"));

      assert.deepEqual(onChange.lastCall.args[0], ["support", "sales"]);
    });

    test("matches held names to groups in any case", async function (assert) {
      const onChange = sinon.spy();

      await render(
        <template>
          <DSelectGroup
            @emit="names"
            @multiple={{true}}
            @onChange={{onChange}}
            @value={{array "Support" "sales"}}
          />
        </template>
      );
      assert
        .dom(".d-select__chip")
        .exists({ count: 2 }, "a held name resolves to its group");

      const select = new DSelect();
      await select.open();
      assert
        .dom(optionNamed("Support crew"))
        .hasAttribute("aria-selected", "true", "the group's row is selected");

      await click(optionNamed("Support crew"));
      assert.deepEqual(
        onChange.lastCall.args[0],
        ["sales"],
        "picking the row removes the held name instead of adding a second one"
      );
    });

    test("lists the call site's own groups instead of the site's", async function (assert) {
      const groups = [{ id: 40, name: "partners", full_name: "Partners" }];

      await render(<template><DSelectGroup @items={{groups}} /></template>);
      await new DSelect().open();

      assert.deepEqual(optionValues(), ["40"]);
    });

    test("caps a multiple selection", async function (assert) {
      await render(
        <template>
          <DSelectGroup @maximum={{1}} @multiple={{true}} @value={{array 10}} />
        </template>
      );
      await new DSelect().open();

      assert
        .dom(optionNamed("sales"))
        .hasAttribute("aria-disabled", "true", "another group can't be added");
    });

    test("is named Group while it holds one, otherwise Groups", async function (assert) {
      const accessibleName = await loadAccessibleName();
      const state = new (class {
        @tracked multiple = false;
        @tracked maximum;
      })();

      await render(
        <template>
          <DSelectGroup
            @maximum={{state.maximum}}
            @multiple={{state.multiple}}
          />
        </template>
      );
      const name = () => accessibleName(find("[role='combobox']"));

      assert.strictEqual(name(), i18n("select_group.group"));
      state.multiple = true;
      await settled();
      assert.strictEqual(name(), i18n("select_group.groups"));
      state.maximum = 1;
      await settled();
      assert.strictEqual(name(), i18n("select_group.group"));
    });

    test("carries the legacy class it replaces", async function (assert) {
      await render(<template><DSelectGroup /></template>);

      assert.dom(".d-select").hasClass("group-chooser");
    });
  }
);
