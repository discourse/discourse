import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import UserMenuTab, {
  CUSTOM_TABS_CLASSES,
  registerUserMenuTab,
  resetUserMenuTabs,
} from "discourse/lib/user-menu/tab";

module("Unit | Utility | user-menu-tab", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.firstOwner = {};
    this.secondOwner = {};
  });

  hooks.afterEach(function () {
    run(() => {
      destroy(this.firstOwner);
      destroy(this.secondOwner);
    });
    resetUserMenuTabs();
  });

  test("old owner cleanup preserves a tab class registered after reset", function (assert) {
    class SharedTab extends UserMenuTab {
      get id() {
        return "owner-lifetime";
      }
    }

    registerUserMenuTab(() => SharedTab, { owner: this.firstOwner });
    resetUserMenuTabs();
    registerUserMenuTab(() => SharedTab, { owner: this.secondOwner });

    run(() => destroy(this.firstOwner));

    assert.true(
      CUSTOM_TABS_CLASSES.some((Tab) => new Tab().id === "owner-lifetime"),
      "the replacement registration still supplies its tab"
    );

    run(() => destroy(this.secondOwner));

    assert.false(
      CUSTOM_TABS_CLASSES.some((Tab) => new Tab().id === "owner-lifetime"),
      "destroying its own owner removes the tab"
    );
  });

  test("removing the last duplicate preserves tab order and constructor identity", function (assert) {
    class SharedTab extends UserMenuTab {
      get id() {
        return "owner-shared";
      }
    }
    class MiddleTab extends UserMenuTab {
      get id() {
        return "owner-middle";
      }
    }
    const tabs = () => CUSTOM_TABS_CLASSES.map((Tab) => new Tab());
    registerUserMenuTab(() => SharedTab, { owner: this.firstOwner });
    registerUserMenuTab(() => MiddleTab);
    registerUserMenuTab(() => SharedTab, { owner: this.secondOwner });

    assert.deepEqual(
      tabs().map((tab) => tab.id),
      ["owner-shared", "owner-middle", "owner-shared"],
      "both registrations retain their insertion positions"
    );

    run(() => destroy(this.secondOwner));
    const remainingTabs = tabs();

    assert.deepEqual(
      remainingTabs.map((tab) => tab.id),
      ["owner-shared", "owner-middle"],
      "the first registration stays before the middle tab"
    );
    assert.strictEqual(
      remainingTabs[0].constructor,
      SharedTab,
      "the tab retains its original constructor"
    );
  });
});
