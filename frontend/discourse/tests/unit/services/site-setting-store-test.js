import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import SiteSetting from "discourse/admin/models/site-setting";
import { isSettingVisible } from "discourse/admin/services/site-setting-store";

function build(attrs) {
  return SiteSetting.create({
    setting: "x",
    value: "",
    type: "integer",
    ...attrs,
  });
}

module("Unit | Service | site-setting-store", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.store = getOwner(this).lookup("service:site-setting-store");
  });

  module("isSettingVisible", function () {
    test("non-hidden settings are always visible", function (assert) {
      const s = build({ depends_behavior: null });
      assert.true(isSettingVisible(s));
      assert.true(isSettingVisible(s, "anything"));
    });

    test("hidden + revealed is visible", function (assert) {
      const s = build({ depends_behavior: "hidden", revealed: true });
      assert.true(isSettingVisible(s));
    });

    test("hidden + unrevealed is not visible without a matching filter", function (assert) {
      const s = build({
        setting: "voting_limit",
        depends_behavior: "hidden",
      });
      assert.false(isSettingVisible(s));
      assert.false(isSettingVisible(s, ""));
      assert.false(isSettingVisible(s, "voting"));
    });

    test("hidden + unrevealed is visible when filter matches name exactly", function (assert) {
      const s = build({
        setting: "voting_limit",
        depends_behavior: "hidden",
      });
      assert.true(isSettingVisible(s, "voting_limit"));
      assert.true(isSettingVisible(s, "voting limit"), "spaces normalize");
      assert.true(isSettingVisible(s, " VOTING_LIMIT "), "case + whitespace");
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
      assert.true(revealed.revealed);
      assert.false(hidden.revealed);
    });

    test("revealed is true when a parent is missing from the store", function (assert) {
      const orphan = build({
        setting: "orphan",
        depends_on: ["missing_parent"],
        depends_behavior: "hidden",
      });
      this.store.register([orphan]);

      assert.true(orphan.revealed);
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
      assert.true(allOn.revealed);

      oneOff.revealed = false;
      this.store.register([
        build({ setting: "a", value: "true" }),
        build({ setting: "b", value: "false" }),
        oneOff,
      ]);
      assert.false(oneOff.revealed);
    });
  });

  module("reveal", function () {
    test("sets revealed=true on hidden-type dependents only", function (assert) {
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

      assert.true(hidden.revealed, "hidden dependent revealed");
      assert.false(plain.revealed, "non-hidden dependent untouched");
      assert.false(unrelated.revealed, "unrelated dependent untouched");
    });
  });
});
