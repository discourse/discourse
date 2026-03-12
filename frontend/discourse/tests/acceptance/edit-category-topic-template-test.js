import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance(
  "Admin - Edit category topic template with simplified category creation",
  function (needs) {
    let putData;

    needs.user({ admin: true });
    needs.settings({
      enable_simplified_category_creation: true,
      enable_form_templates: true,
    });

    needs.pretender((server, helper) => {
      server.get("/form-templates.json", () => {
        return helper.response(200, {
          form_templates: [
            { id: 1, name: "Template 1" },
            { id: 2, name: "Template 2" },
          ],
        });
      });

      server.get("/c/bug/find_by_slug.json", () => {
        return helper.response(200, {
          category: {
            id: 11,
            name: "bug",
            slug: "bug",
            can_edit: true,
            category_type_site_settings: {},
            permissions: [],
          },
        });
      });

      server.put("/categories/:id", (request) => {
        putData = JSON.parse(request.requestBody);
        return helper.response(200, {
          category: {
            id: request.params.id,
            name: "bug",
            can_edit: true,
            category_type_site_settings: {},
            permissions: [],
            ...putData,
          },
        });
      });
    });

    test("Changing topic template shows the unsaved changes banner", async function (assert) {
      putData = null;
      await visit("/c/bug/edit/topic-template");

      await fillIn(".d-editor-input", "New topic template content");

      assert
        .dom(".admin-changes-banner")
        .exists("banner is shown after changing topic template");

      await click(".admin-changes-banner .btn-primary");

      assert.strictEqual(
        putData.topic_template,
        "New topic template content",
        "it sends the updated topic template"
      );
    });

    test("Selecting a form template shows the unsaved changes banner", async function (assert) {
      putData = null;
      await visit("/c/bug/edit/topic-template");

      await click(".toggle-template-type");

      const formTemplateChooser = selectKit(".form-template-chooser");
      await formTemplateChooser.expand();
      await formTemplateChooser.selectRowByValue(1);

      assert
        .dom(".admin-changes-banner")
        .exists("banner is shown after selecting a form template");

      await click(".admin-changes-banner .btn-primary");

      assert.deepEqual(
        putData.form_template_ids,
        [1],
        "it sends the updated form template ids"
      );
      assert
        .dom(".admin-changes-banner")
        .doesNotExist("banner is gone after saving");
    });
  }
);

acceptance("Admin - Legacy edit category topic template", function (needs) {
  let putData;

  needs.user({ admin: true });
  needs.settings({
    enable_simplified_category_creation: false,
  });

  needs.pretender((server, helper) => {
    server.get("/c/bug/find_by_slug.json", () => {
      return helper.response(200, {
        category: {
          id: 11,
          name: "bug",
          slug: "bug",
          can_edit: true,
          topic_template: "Existing template content",
          category_type_site_settings: {},
          permissions: [],
        },
      });
    });

    server.put("/categories/:id", (request) => {
      putData = JSON.parse(request.requestBody);
      return helper.response(200, {
        category: {
          id: request.params.id,
          name: "bug",
          can_edit: true,
          category_type_site_settings: {},
          permissions: [],
          ...putData,
        },
      });
    });
  });

  test("Changing topic template saves correctly", async function (assert) {
    putData = null;
    await visit("/c/bug/edit/topic-template");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "Existing template content",
        "it loads the existing template content"
      );

    await fillIn(".d-editor-input", "Legacy flow template content");

    await click("#save-category");

    assert.strictEqual(
      putData.topic_template,
      "Legacy flow template content",
      "it sends the updated topic template in legacy flow"
    );
  });
});
