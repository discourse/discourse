import EmberObject, { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

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
    this.siteSettings = getOwner(this).lookup("service:site-settings");
  });

  test("contains settings", function (assert) {
    assert.strictEqual(typeof this.siteSettings.title, "string");
  });

  test("notifies getters", function (assert) {
    this.siteSettings.title = "original";

    getOwner(this).register("test-class:main", TestClass);
    const object = getOwner(this).lookup("test-class:main");
    assert.strictEqual(object.text, "The title: original");

    this.siteSettings.title = "updated";
    assert.strictEqual(object.text, "The title: updated");
  });
});
