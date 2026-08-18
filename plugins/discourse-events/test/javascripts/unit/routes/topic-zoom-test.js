import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

const HIDE_SIDEBAR_KEY = "sidebar-hidden";

function hasStoredClosePreference(keyValueStore) {
  return !!keyValueStore.getItem(HIDE_SIDEBAR_KEY);
}

module("Unit | Route | topic-zoom", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const owner = getOwner(this);

    this.applicationController = {
      _showSidebar: null,
      get showSidebar() {
        return this._showSidebar;
      },
      set showSidebar(value) {
        this._showSidebar = value;
      },
    };

    this.topicController = {
      set(field, value) {
        this[field] = value;
      },
    };

    owner.unregister("service:embeddable-chat");
    owner.register(
      "service:embeddable-chat",
      { closeChatVisibility: () => {} },
      { instantiate: false }
    );

    this.subject = owner.lookup("route:topic-zoom");
    // The route hands its application/topic controller to the app; only the
    // values it sets on them are under test.
    this.subject.controllerFor = (name) =>
      name === "application"
        ? this.applicationController
        : this.topicController;

    this.keyValueStore = owner.lookup("service:key-value-store");
    this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);
  });

  hooks.afterEach(function () {
    this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);
  });

  test("collapses the sidebar on activation and restores it on exit", function (assert) {
    this.subject.activate();

    assert.false(
      this.applicationController.showSidebar,
      "the sidebar is collapsed while on the /zoom page"
    );

    this.subject.deactivate();

    assert.strictEqual(
      this.applicationController.showSidebar,
      null,
      "the override is dropped on exit so the stored preference governs again"
    );
    assert.false(
      hasStoredClosePreference(this.keyValueStore),
      "a passive visit leaves the stored preference untouched"
    );
  });

  test("rolls back a manual toggle from an open preference", function (assert) {
    // The user prefers the sidebar open (no stored key). While on /zoom they
    // toggle it closed, which core's toggleSidebar persists.
    this.subject.activate();

    this.applicationController.showSidebar = false;
    this.keyValueStore.setItem(HIDE_SIDEBAR_KEY, "true");

    this.subject.deactivate();

    assert.false(
      hasStoredClosePreference(this.keyValueStore),
      "the next pages still open the sidebar"
    );
  });

  test("rolls back a manual toggle from a closed preference", function (assert) {
    // The user prefers the sidebar closed. While on /zoom they toggle it open.
    this.keyValueStore.setItem(HIDE_SIDEBAR_KEY, "true");

    this.subject.activate();

    this.applicationController.showSidebar = true;
    this.keyValueStore.removeItem(HIDE_SIDEBAR_KEY);

    this.subject.deactivate();

    assert.strictEqual(
      this.keyValueStore.getItem(HIDE_SIDEBAR_KEY),
      "true",
      "the next pages keep the sidebar closed"
    );
  });
});
