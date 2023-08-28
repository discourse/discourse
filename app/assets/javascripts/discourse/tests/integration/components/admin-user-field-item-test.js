import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { click, render } from "@ember/test-helpers";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

module("Integration | Component | admin-user-field-item", function (hooks) {
  setupRenderingTest(hooks);

  test("user field without an id", async function (assert) {
    await render(hbs`<AdminUserFieldItem @userField={{this.userField}} />`);

    assert.ok(exists(".save"), "displays editing mode");
  });

  test("cancel action", async function (assert) {
    this.set("userField", { id: 1, field_type: "text" });
    this.set("isEditing", true);

    await render(
      hbs`<AdminUserFieldItem @isEditing={{this.isEditing}} @destroyAction={{this.destroyAction}} @userField={{this.userField}} />`
    );

    await click(".cancel");
    assert.ok(exists(".edit"));
  });

  test("edit action", async function (assert) {
    this.set("userField", { id: 1, field_type: "text" });

    await render(
      hbs`<AdminUserFieldItem @destroyAction={{this.destroyAction}} @userField={{this.userField}} />`
    );

    await click(".edit");
    assert.ok(exists(".save"));
  });

  test("field attributes are rendered correctly", async function (assert) {
    this.set("userField", {
      id: 1,
      field_type: "text",
      name: "foo",
      description: "what is foo",
      show_on_profile: true,
      show_on_user_card: true,
      searchable: true,
    });

    await render(hbs`<AdminUserFieldItem @userField={{this.userField}} />`);

    assert.strictEqual(query(".name").innerText, this.userField.name);
    assert.strictEqual(
      query(".description").innerText,
      this.userField.description
    );
    assert.strictEqual(
      query(".field-type").innerText,
      I18n.t("admin.user_fields.field_types.text")
    );

    assert
      .dom(".user-field-flags")
      .hasText(
        `${I18n.t("admin.user_fields.show_on_profile.enabled")}, ${I18n.t(
          "admin.user_fields.show_on_user_card.enabled"
        )}, ${I18n.t("admin.user_fields.searchable.enabled")}`
      );
  });
});
