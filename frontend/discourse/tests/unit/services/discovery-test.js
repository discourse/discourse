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

  test("showingSubcategoryList is true on a category's topic list", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.latest", {
      category: { id: 1 },
    });

    assert.true(discovery.showingSubcategoryList);
  });

  test("showingSubcategoryList is false on the categories page", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.categories");

    assert.false(discovery.showingSubcategoryList);
  });

  test("showingSubcategoryList is false on a category's subcategories page", function (assert) {
    const discovery = stubRouter(getOwner(this), "discovery.subcategories", {
      category: { id: 1 },
    });

    assert.false(discovery.showingSubcategoryList);
  });

  test("showingSubcategoryList is false away from discovery", function (assert) {
    const discovery = stubRouter(getOwner(this), "topic.fromParamsNear", {
      category: { id: 1 },
    });

    assert.false(discovery.showingSubcategoryList);
  });
});
