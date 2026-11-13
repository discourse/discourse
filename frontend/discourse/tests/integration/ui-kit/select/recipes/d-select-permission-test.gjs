import { hash } from "@ember/helper";
import { click, find, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadAccessibleName from "discourse/lib/load-accessible-name";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { DSelect } from "discourse/tests/helpers/d-select-helper";
import DSelectPermission from "discourse/ui-kit/select/recipes/permissions/d-select-permission";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const PERMISSIONS = [
  { id: "view", name: "Viewer", description: "Can view content" },
  { id: "edit", name: "Editor", description: "Can edit content" },
];

/** The listed rows in order: option values, with `|` for each divider. */
function listedRows() {
  return findAll(".d-select__option, .d-select__divider").map((row) =>
    row.classList.contains("d-select__divider") ? "|" : row.dataset.value
  );
}

/** The texts an element's `aria-describedby` points at, in order. */
function descriptions(element) {
  return (element.getAttribute("aria-describedby") ?? "")
    .split(/\s+/)
    .filter(Boolean)
    .map((id) => document.getElementById(id)?.textContent.trim());
}

/** The option for a value. */
function option(value) {
  return find(`[role='option'][data-value='${value}']`);
}

module(
  "Integration | ui-kit | select | recipes | DSelectPermission",
  function (hooks) {
    setupRenderingTest(hooks);

    test("lists the permissions with their descriptions and shows the held one", async function (assert) {
      await render(
        <template>
          <DSelectPermission @options={{PERMISSIONS}} @value="edit" />
        </template>
      );

      assert.dom("[role='combobox']").includesText("Editor");

      await new DSelect().open();

      assert.deepEqual(listedRows(), ["view", "edit"]);
      assert
        .dom(".d-select__option-description", option("view"))
        .hasText("Can view content");
      assert.dom(option("edit")).hasAttribute("aria-selected", "true");
    });

    test("emits the picked permission's id", async function (assert) {
      const emitted = [];
      const onChange = (permission) => emitted.push(permission);

      await render(
        <template>
          <DSelectPermission
            @onChange={{onChange}}
            @options={{PERMISSIONS}}
            @value="edit"
          />
        </template>
      );
      await new DSelect().select("view");

      assert.deepEqual(emitted, ["view"]);
    });

    test("offers Remove only with @onRemove, after a divider", async function (assert) {
      await render(
        <template><DSelectPermission @options={{PERMISSIONS}} /></template>
      );
      await new DSelect().open();

      assert.deepEqual(listedRows(), ["view", "edit"], "no Remove without it");
    });

    test("Remove runs @onRemove instead of picking, and closes the list", async function (assert) {
      const emitted = [];
      let removed = 0;
      const onChange = (permission) => emitted.push(permission);
      const onRemove = () => removed++;

      await render(
        <template>
          <DSelectPermission
            @onChange={{onChange}}
            @onRemove={{onRemove}}
            @options={{PERMISSIONS}}
            @value="view"
          />
        </template>
      );
      await new DSelect().open();

      assert.deepEqual(listedRows(), ["view", "edit", "|", "remove"]);
      assert
        .dom(option("remove"))
        .includesText(i18n("access_control.manage.access_permission_remove"));
      assert
        .dom(".d-select__option-description", option("remove"))
        .hasText(
          i18n("access_control.manage.access_permission_remove_description")
        );

      await click(option("remove"));

      assert.strictEqual(removed, 1, "removes once");
      assert.deepEqual(emitted, [], "picks nothing");
      assert.dom("[role='listbox']").doesNotExist("the list closes");
    });

    test("Remove is named by its label and described once", async function (assert) {
      const accessibleName = await loadAccessibleName();
      const onRemove = () => {};

      await render(
        <template>
          <DSelectPermission @onRemove={{onRemove}} @options={{PERMISSIONS}} />
        </template>
      );
      await new DSelect().open();

      assert.strictEqual(
        accessibleName(option("remove")),
        i18n("access_control.manage.access_permission_remove"),
        "the name is the label alone"
      );
      assert.deepEqual(
        descriptions(option("remove")),
        [i18n("access_control.manage.access_permission_remove_description")],
        "the description is read once"
      );
    });

    test("a caller's disabled permission stays disabled and keeps its description", async function (assert) {
      const options = [
        selectOption(PERMISSIONS[0], { disabled: true }),
        PERMISSIONS[1],
      ];

      await render(
        <template><DSelectPermission @options={{options}} /></template>
      );
      await new DSelect().open();

      assert.dom(option("view")).hasAttribute("aria-disabled", "true");
      assert
        .dom(".d-select__option-description", option("view"))
        .hasText("Can view content");
      assert.dom(option("edit")).doesNotHaveAttribute("aria-disabled");
    });

    test("Remove's wording comes from its texts", async function (assert) {
      const onRemove = () => {};

      await render(
        <template>
          <DSelectPermission
            @onRemove={{onRemove}}
            @options={{PERMISSIONS}}
            @texts={{hash
              removeLabel="Revoke access"
              removeDescription="Takes every permission away"
            }}
          />
        </template>
      );
      await new DSelect().open();

      assert.dom(option("remove")).includesText("Revoke access");
      assert
        .dom(".d-select__option-description", option("remove"))
        .hasText("Takes every permission away");
    });

    test("is named Permission unless the call site names it, and takes an id", async function (assert) {
      const accessibleName = await loadAccessibleName();

      await render(
        <template>
          <DSelectPermission
            @id="row-permission"
            @options={{PERMISSIONS}}
            @value="view"
          />
          <DSelectPermission
            @options={{PERMISSIONS}}
            @texts={{hash ariaLabel="Permission for sam"}}
            @value="view"
          />
        </template>
      );
      const [named, custom] = findAll("[role='combobox']");

      assert.true(
        accessibleName(named).startsWith(i18n("select_permission.permission")),
        "the default name"
      );
      assert.true(
        accessibleName(custom).startsWith("Permission for sam"),
        "the call site's name"
      );
      assert.strictEqual(named.id, "row-permission");
    });

    test("can't be opened when disabled", async function (assert) {
      await render(
        <template>
          <DSelectPermission
            @disabled={{true}}
            @options={{PERMISSIONS}}
            @value="view"
          />
        </template>
      );
      await click("[role='combobox']");

      assert.dom("[role='listbox']").doesNotExist();
    });
  }
);
