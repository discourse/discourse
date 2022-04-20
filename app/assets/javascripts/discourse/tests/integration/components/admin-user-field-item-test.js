import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import I18n from "I18n";
import { click } from "@ember/test-helpers";

discourseModule(
  "Integration | Component | admin-user-field-item",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("user field without an id", {
      template: hbs`{{admin-user-field-item userField=userField}}`,

      async test(assert) {
        assert.ok(exists(".save"), "displays editing mode");
      },
    });

    componentTest("cancel action", {
      template: hbs`{{admin-user-field-item isEditing=isEditing destroyAction=destroyAction userField=userField}}`,

      beforeEach() {
        this.set("userField", { id: 1, field_type: "text" });
        this.set("isEditing", true);
      },

      async test(assert) {
        await click(".cancel");
        assert.ok(exists(".edit"));
      },
    });

    componentTest("edit action", {
      template: hbs`{{admin-user-field-item destroyAction=destroyAction userField=userField}}`,

      beforeEach() {
        this.set("userField", { id: 1, field_type: "text" });
      },

      async test(assert) {
        await click(".edit");
        assert.ok(exists(".save"));
      },
    });

    componentTest("user field with an id", {
      template: hbs`{{admin-user-field-item userField=userField}}`,

      beforeEach() {
        this.set("userField", {
          id: 1,
          field_type: "text",
          name: "foo",
          description: "what is foo",
        });
      },

      async test(assert) {
        assert.equal(query(".name").innerText, this.userField.name);
        assert.equal(
          query(".description").innerText,
          this.userField.description
        );
        assert.equal(
          query(".field-type").innerText,
          I18n.t("admin.user_fields.field_types.text")
        );
      },
    });
  }
);
