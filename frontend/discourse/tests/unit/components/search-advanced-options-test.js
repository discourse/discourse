import { destroy } from "@ember/destroyable";
import { run } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { addAdvancedSearchOptions } from "discourse/components/search-advanced-options";

module("Unit | Component | SearchAdvancedOptions", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.firstOwner = {};
    this.secondOwner = {};
    this.components = [];
  });

  hooks.afterEach(function () {
    run(() => {
      this.components.forEach((component) => component.destroy());
      destroy(this.firstOwner);
      destroy(this.secondOwner);
    });
  });

  test("owner disposal preserves option identity, order and application registrations", function (assert) {
    const sharedStatus = { name: "Shared", value: "owner-shared" };
    const applicationStatus = {
      name: "Application",
      value: "owner-application",
    };
    const sharedOptions = { statusOptions: [sharedStatus] };
    addAdvancedSearchOptions(sharedOptions, { owner: this.firstOwner });
    addAdvancedSearchOptions(
      { statusOptions: [applicationStatus] },
      { owner: this.owner }
    );
    addAdvancedSearchOptions(sharedOptions, { owner: this.secondOwner });

    run(() => destroy(this.secondOwner));
    sharedStatus.name = "Updated";
    const component = this.owner
      .factoryFor("component:search-advanced-options")
      .create();
    this.components.push(component);
    const statuses = component.statusOptions.filter((status) =>
      status.value.startsWith("owner-")
    );

    assert.deepEqual(
      statuses.map((status) => status.name),
      ["Updated", "Application"],
      "the first registration retains its order and live changes"
    );
    assert.strictEqual(
      statuses[0],
      sharedStatus,
      "the original status option is preserved"
    );

    run(() => destroy(this.firstOwner));
    const nextComponent = this.owner
      .factoryFor("component:search-advanced-options")
      .create();
    this.components.push(nextComponent);

    assert.deepEqual(
      nextComponent.statusOptions.filter((status) =>
        status.value.startsWith("owner-")
      ),
      [applicationStatus],
      "a fresh component keeps only the application-owned filter"
    );
  });
});
