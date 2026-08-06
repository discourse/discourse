import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  isComposite,
  itemRolesFor,
  requiredPropsFor,
  requiresAccessibleName,
} from "discourse/static/dev-tools/a11y/aria";

/**
 * Oracle for the role-metadata facade (unit 1).
 *
 * Every assertion here is a claim about ARIA, not about `aria-query`'s shape.
 * The facade exists so the rest of the panel never reads that shape directly,
 * and so the composite table stops being hand-maintained — these tests are what
 * keeps the derivation honest when the library is upgraded under us.
 */
module("Unit | Lib | dev-tools | a11y-aria", function (hooks) {
  setupTest(hooks);

  test("the eight real composite roles derive, and nothing else does", function (assert) {
    for (const role of [
      "grid",
      "listbox",
      "menu",
      "menubar",
      "radiogroup",
      "tablist",
      "tree",
      "treegrid",
    ]) {
      assert.true(isComposite(role), `${role} is composite`);
    }

    // `select` derives as composite from its superClass chain but is an
    // abstract role that may not appear in markup, and `spinbutton` derives as
    // composite while owning no items at all. Both must be excluded, or the
    // cursor rules acquire subjects that cannot have a cursor.
    assert.false(isComposite("select"), "abstract roles are not composites");
    assert.false(
      isComposite("spinbutton"),
      "a composite that owns nothing is not one for our purposes"
    );

    for (const role of ["button", "link", "list", "region", "dialog"]) {
      assert.false(isComposite(role), `${role} is not composite`);
    }

    assert.false(isComposite("not-a-real-role"), "an unknown role is not one");
  });

  test("item roles come from the role, not from a listbox assumption", function (assert) {
    assert.deepEqual(
      [...itemRolesFor("listbox")].sort(),
      ["option"],
      "listbox owns options"
    );
    assert.deepEqual(
      [...itemRolesFor("tablist")].sort(),
      ["tab"],
      "tablist owns tabs"
    );
    assert.deepEqual(
      [...itemRolesFor("radiogroup")].sort(),
      ["radio"],
      "radiogroup owns radios"
    );

    const menuItems = itemRolesFor("menu");
    for (const role of ["menuitem", "menuitemcheckbox", "menuitemradio"]) {
      assert.true(menuItems.has(role), `menu owns ${role}`);
    }
  });

  // `group` and `rowgroup` are structural wrappers, not cursor targets. A
  // composite's `aria-activedescendant` pointing at a `group` is the
  // "points at a wrapper" defect, so they must never be admitted as items.
  test("structural wrappers are never cursor targets", function (assert) {
    assert.false(itemRolesFor("listbox").has("group"), "listbox: not group");
    assert.false(itemRolesFor("tree").has("group"), "tree: not group");
    assert.false(itemRolesFor("grid").has("rowgroup"), "grid: not rowgroup");
  });

  // grid owns `row`; `row` owns the cells. A grid's cursor legitimately targets
  // a gridcell, so the derivation has to take one transitive step or every
  // correct grid reports its cursor as pointing outside the composite.
  test("a grid reaches its cells through row", function (assert) {
    const gridItems = itemRolesFor("grid");

    assert.true(gridItems.has("row"), "row is a direct item");
    for (const cell of ["gridcell", "columnheader", "rowheader"]) {
      assert.true(gridItems.has(cell), `${cell} is reachable through row`);
    }
  });

  // `cell` is the non-interactive table variant; a grid's cursor targets
  // `gridcell`. Both are reachable through `row`, so a derivation that filters
  // only the obvious structural wrappers admits `cell` and reports a correct
  // grid cursor as pointing at a legitimate item it can never actually be.
  test("a grid admits gridcell but not the non-interactive cell", function (assert) {
    for (const role of ["grid", "treegrid"]) {
      const items = itemRolesFor(role);

      assert.true(items.has("gridcell"), `${role} owns gridcell`);
      assert.false(
        items.has("cell"),
        `${role} does not admit cell, which is not an interactive target`
      );
    }
  });

  test("an unknown role owns nothing rather than throwing", function (assert) {
    assert.deepEqual([...itemRolesFor("not-a-real-role")], []);
    assert.deepEqual([...itemRolesFor("button")], []);
  });

  test("required props carry the default the spec supplies", function (assert) {
    const option = requiredPropsFor("option");
    assert.true(
      option.has("aria-selected"),
      "option requires aria-selected per aria-query"
    );
    assert.strictEqual(
      option.get("aria-selected"),
      "false",
      "and the spec supplies false, which is why its absence is FRAGILE not BROKEN"
    );

    const checkbox = requiredPropsFor("checkbox");
    assert.true(checkbox.has("aria-checked"), "checkbox requires aria-checked");
    assert.strictEqual(
      checkbox.get("aria-checked"),
      null,
      "with no default, which is why its absence is BROKEN"
    );

    assert.strictEqual(
      requiredPropsFor("button").size,
      0,
      "a role with no required props reports none"
    );
    assert.strictEqual(requiredPropsFor("not-a-real-role").size, 0);
  });

  test("accessible-name requirement is read from the role table", function (assert) {
    assert.true(requiresAccessibleName("option"), "an option must be named");
    assert.true(requiresAccessibleName("button"), "a button must be named");
    assert.false(
      requiresAccessibleName("generic"),
      "a generic element need not be"
    );
    assert.false(requiresAccessibleName("not-a-real-role"));
  });

  // The whole point of the facade: the hand-written table it replaces stays
  // covered. If a library upgrade drops one of these, this fails rather than
  // the cursor rules silently going quiet.
  test("the derivation covers every role the hand-written table listed", function (assert) {
    const handWritten = {
      listbox: ["option"],
      menu: ["menuitem", "menuitemcheckbox", "menuitemradio"],
      menubar: ["menuitem", "menuitemcheckbox", "menuitemradio"],
      tree: ["treeitem"],
      grid: ["row", "gridcell", "rowheader", "columnheader"],
      treegrid: ["row", "gridcell", "rowheader", "columnheader"],
      tablist: ["tab"],
      radiogroup: ["radio"],
    };

    for (const [role, items] of Object.entries(handWritten)) {
      assert.true(isComposite(role), `${role} still derives as composite`);
      const derived = itemRolesFor(role);
      for (const item of items) {
        assert.true(derived.has(item), `${role} still owns ${item}`);
      }
    }
  });
});
