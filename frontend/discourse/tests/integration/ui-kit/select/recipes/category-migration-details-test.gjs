import { click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import ReportCategory from "discourse/admin/components/report-filters/category";
import PreferenceCategories from "discourse/components/user-preferences/categories";
import Category from "discourse/models/category";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import { i18n } from "discourse-i18n";

module(
  "Integration | ui-kit | select | category migration details",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.siteSettings.enable_new_select_controls = true;
    });

    test("notification preferences exclude other held records and keep their own records", async function (assert) {
      const watched = Category.findById(1);
      const tracked = Category.findById(2);
      const added = Category.findById(3);
      const model = {
        watchedCategories: [watched],
        trackedCategories: [tracked],
        watchedFirstPostCategories: [],
        mutedCategories: [],
      };
      const selected = [watched, tracked];
      await render(
        <template>
          <PreferenceCategories
            @model={{model}}
            @selectedCategories={{selected}}
            @siteSettings={{this.siteSettings}}
          />
        </template>
      );
      const picker = new DSelect(
        ".tracking-controls__watched-categories .d-select"
      );
      await picker.open();
      const values = findAll("[role='option'][data-value]").map(
        (row) => row.dataset.value
      );
      assert.true(
        values.includes(String(watched.id)),
        "the current field retains its category"
      );
      assert.false(
        values.includes(String(tracked.id)),
        "another field's category is excluded"
      );
      await picker.select(added.id);
      assert.deepEqual(
        model.watchedCategories,
        [watched, added],
        "the callback stores category records"
      );
    });

    test("the report filter uses a placeholder and emits ids when cleared", async function (assert) {
      const applyFilter = sinon.spy();
      const filter = { id: "category", default: 1 };
      await render(
        <template>
          <ReportCategory @applyFilter={{applyFilter}} @filter={{filter}} />
        </template>
      );
      const picker = new DSelect();
      await picker.clear();
      assert.true(
        applyFilter.calledOnceWithExactly("category", undefined),
        "clearing removes the report filter"
      );
      await picker.open();
      assert
        .dom("[role='option'][data-value='category-none']")
        .doesNotExist("the all-categories text is a placeholder");
      await picker.select(2);
      assert.true(
        applyFilter.calledWithExactly("category", 2),
        "the filter receives an id"
      );
    });

    test("a disabled report category cannot open", async function (assert) {
      const filter = { id: "category", disabled: true };
      await render(<template><ReportCategory @filter={{filter}} /></template>);
      assert
        .dom(".d-select__input")
        .isDisabled("the argument locks the control");
      assert
        .dom(".d-select__input")
        .hasAttribute(
          "placeholder",
          i18n("category.all"),
          "the translated empty label is preserved"
        );
      await click(".d-select");
      assert
        .dom(".d-select__panel")
        .doesNotExist("the disabled control stays closed");
    });
  }
);
