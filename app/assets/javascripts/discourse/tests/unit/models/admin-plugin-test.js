import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import AdminPlugin from "admin/models/admin-plugin";

module("Unit | Model | admin plugin", function (hooks) {
  setupTest(hooks);

  test("nameTitleized", function (assert) {
    const adminPlugin = AdminPlugin.create({
      name: "docker_manager",
    });

    assert.strictEqual(
      adminPlugin.nameTitleized,
      "Docker Manager",
      "it should return titleized name replacing underscores with spaces"
    );
  });
});
