import { getOwner } from "@ember/owner";
import Service from "@ember/service";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | discovery", function (hooks) {
  setupTest(hooks);

  function stubRouter(owner, currentRouteName, attributes = {}) {
    class RouterStub extends Service {
      currentRouteName = currentRouteName;
      currentRoute = { attributes };
    }

    owner.unregister("service:router");
    owner.register("service:router", RouterStub);

    return owner.lookup("service:discovery");
  }

  test("categoryListPage names the categories page", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.categories");

    assert.strictEqual(discovery.categoryListPage, "categories");
  });

  test("categoryListPage names a category's subcategories page", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.subcategories", {
      category: { id: 1 },
    });

    assert.strictEqual(discovery.categoryListPage, "subcategories");
  });

  test("categoryListPage names a category's topic list", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.latest", {
      category: { id: 1 },
    });

    assert.strictEqual(discovery.categoryListPage, "category");
  });

  test("categoryListPage is undefined without a category listing", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.latest");

    assert.strictEqual(discovery.categoryListPage, undefined);
  });

  test("categoryListPage is undefined away from discovery", function (assert) {
    const discovery = stubRouter(getOwner(this), "topic.fromParamsNear", {
      category: { id: 1 },
    });

    assert.strictEqual(discovery.categoryListPage, undefined);
  });
});
