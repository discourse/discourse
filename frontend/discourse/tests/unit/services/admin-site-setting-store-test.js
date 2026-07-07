import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";

function build(attrs) {
  return SiteSetting.create({
    setting: "x",
    value: "",
    type: "integer",
    ...attrs,
  });
}

module("Unit | Service | admin-site-setting-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:admin-site-setting-store");
  });

  module("isVisible", function () {
    test("non-hidden settings are always visible", function (assert) {
      const s = build({ depends_behavior: null });
      this.store.register([s]);
      assert.true(this.store.isVisible(s));
      assert.true(this.store.isVisible(s, "anything"));
    });

    test("hidden + revealed is visible", function (assert) {
      const parent = build({ setting: "parent", value: "true" });
      const child = build({
        setting: "child",
        depends_on: ["parent"],
        depends_behavior: "hidden",
      });
      this.store.register([parent, child]);
      assert.true(this.store.isVisible(child));
    });

    test("hidden + unrevealed is not visible without a matching filter", function (assert) {
      const s = build({
        setting: "voting_limit",
        depends_on: ["parent"],
        depends_behavior: "hidden",
      });
      this.store.register([build({ setting: "parent", value: "false" }), s]);
      assert.false(this.store.isVisible(s));
      assert.false(this.store.isVisible(s, ""));
      assert.false(this.store.isVisible(s, "voting"));
    });

    test("hidden + unrevealed is visible when filter matches name exactly", function (assert) {
      const s = build({
        setting: "voting_limit",
        depends_on: ["parent"],
        depends_behavior: "hidden",
      });
      this.store.register([build({ setting: "parent", value: "false" }), s]);
      assert.true(this.store.isVisible(s, "voting_limit"));
      assert.true(this.store.isVisible(s, "voting limit"), "spaces normalize");
      assert.true(
        this.store.isVisible(s, " VOTING_LIMIT "),
        "case + whitespace"
      );
    });

    test("hidden value-dependent settings are visible only when the parent has a matching value", function (assert) {
      const parent = build({ setting: "category_scope", value: "public" });
      const child = build({
        setting: "highlight_categories",
        depends_on: ["category_scope"],
        depends_on_values: {
          category_scope: ["include", "exclude"],
        },
        depends_behavior: "hidden",
      });
      this.store.register([parent, child]);

      assert.false(this.store.isVisible(child));

      parent.buffered.set("value", "include");
      assert.true(this.store.isVisible(child));

      parent.buffered.set("value", "public");
      assert.false(
        this.store.isVisible(child),
        "the dependent setting is hidden again when the parent value no longer matches"
      );
    });

    test("inline dependent settings are hidden from the top-level list unless directly filtered", function (assert) {
      const child = build({
        setting: "highlight_categories",
        depends_on: ["category_scope"],
        depends_on_values: {
          category_scope: ["include"],
        },
        depends_behavior: "hidden",
        dependent_setting_display: "inline",
      });
      this.store.register([
        build({ setting: "category_scope", value: "include" }),
        child,
      ]);

      assert.false(this.store.isVisible(child));
      assert.true(this.store.isVisible(child, "highlight_categories"));
    });
  });

  module("inlineDependentSettings", function () {
    test("returns matching inline dependents for a setting", function (assert) {
      const parent = build({ setting: "category_scope", value: "public" });
      const child = build({
        setting: "highlight_categories",
        depends_on: ["category_scope"],
        depends_on_values: {
          category_scope: ["include"],
        },
        depends_behavior: "hidden",
        dependent_setting_display: "inline",
      });
      const separateChild = build({
        setting: "separate_categories",
        depends_on: ["category_scope"],
        depends_on_values: {
          category_scope: ["include"],
        },
        depends_behavior: "hidden",
      });
      this.store.register([parent, child, separateChild]);

      assert.deepEqual(this.store.inlineDependentSettings(parent), []);

      parent.buffered.set("value", "include");
      assert.deepEqual(this.store.inlineDependentSettings(parent), [child]);
    });
  });

  module("register", function () {
    test("populates byName and latches revealed from parent values", function (assert) {
      const parent = build({ setting: "parent_flag", value: "true" });
      const revealed = build({
        setting: "revealed_child",
        depends_on: ["parent_flag"],
        depends_behavior: "hidden",
      });
      const hidden = build({
        setting: "hidden_child",
        depends_on: ["off_flag"],
        depends_behavior: "hidden",
      });
      this.store.register([
        parent,
        revealed,
        hidden,
        build({ setting: "off_flag", value: "false" }),
      ]);

      assert.strictEqual(this.store.get("parent_flag"), parent);
      assert.true(this.store.isRevealed(revealed));
      assert.false(this.store.isRevealed(hidden));
    });

    test("revealed is true when a parent is missing from the store", function (assert) {
      const orphan = build({
        setting: "orphan",
        depends_on: ["missing_parent"],
        depends_behavior: "hidden",
      });
      this.store.register([orphan]);

      assert.true(this.store.isRevealed(orphan));
    });

    test("multi-parent: revealed only if all parents are truthy", function (assert) {
      const allOn = build({
        setting: "all_on",
        depends_on: ["a", "b"],
        depends_behavior: "hidden",
      });
      const oneOff = build({
        setting: "one_off",
        depends_on: ["a", "b"],
        depends_behavior: "hidden",
      });
      this.store.register([
        build({ setting: "a", value: "true" }),
        build({ setting: "b", value: "true" }),
        allOn,
        oneOff,
      ]);
      assert.true(this.store.isRevealed(allOn));

      this.store.register([
        build({ setting: "a", value: "true" }),
        build({ setting: "b", value: "false" }),
        oneOff,
      ]);
      assert.false(this.store.isRevealed(oneOff));
    });

    test("value-dependent settings are not latched as revealed", function (assert) {
      const parent = build({ setting: "scope", value: "include" });
      const child = build({
        setting: "categories",
        depends_on: ["scope"],
        depends_on_values: {
          scope: ["include"],
        },
        depends_behavior: "hidden",
      });
      this.store.register([parent, child]);

      assert.true(this.store.isRevealed(child));

      parent.buffered.set("value", "public");
      assert.false(this.store.isRevealed(child));
    });
  });

  module("reveal", function () {
    test("reveals hidden-type dependents only", function (assert) {
      const hidden = build({
        setting: "child_a",
        depends_on: ["flag"],
        depends_behavior: "hidden",
      });
      const plain = build({
        setting: "child_b",
        depends_on: ["flag"],
      });
      const unrelated = build({
        setting: "child_c",
        depends_on: ["other"],
        depends_behavior: "hidden",
      });
      this.store.register([
        build({ setting: "flag", value: "false" }),
        build({ setting: "other", value: "false" }),
        hidden,
        plain,
        unrelated,
      ]);

      this.store.reveal("flag");

      assert.true(this.store.isRevealed(hidden), "hidden dependent revealed");
      assert.false(
        this.store.isRevealed(plain),
        "non-hidden dependent untouched"
      );
      assert.false(
        this.store.isRevealed(unrelated),
        "unrelated dependent untouched"
      );
    });
  });
});
