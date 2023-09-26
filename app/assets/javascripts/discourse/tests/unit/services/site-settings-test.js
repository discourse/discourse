import { module, test } from "qunit";
import { setupTest } from "ember-qunit";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { inject as service } from "@ember/service";
import EmberObject, { computed } from "@ember/object";

class TestClass extends EmberObject {
  @service siteSettings;

  @computed("siteSettings.title")
  get text() {
    return `The title: ${this.siteSettings.title}`;
  }
}

module("Unit | Service | site-settings", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings = getOwnerWithFallback(this).lookup(
      "service:site-settings"
    );
  });

  test("contains settings", function (assert) {
    assert.ok(this.siteSettings.title);
  });

  test("notifies getters", function (assert) {
    this.siteSettings.title = "original";

    getOwnerWithFallback(this).register("test-class:main", TestClass);
    const object = getOwnerWithFallback(this).lookup("test-class:main");
    assert.strictEqual(object.text, "The title: original");

    this.siteSettings.title = "updated";
    assert.strictEqual(object.text, "The title: updated");
  });
});
