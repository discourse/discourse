import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance(
  "Composer disabled, uncategorized not allowed when any topic_template present",
  function (needs) {
    needs.user();
    needs.settings({
      enable_whispers: true,
      allow_uncategorized_topics: false,
    });

    test("Disable body until category is selected", async function (assert) {
      await visit("/");
      await click("#create-topic");
      assert.ok(exists(".d-editor-input"), "the composer input is visible");
      assert.ok(
        exists(".title-input .popup-tip.bad.hide"),
        "title errors are hidden by default"
      );
      assert.ok(
        exists(".d-editor-textarea-wrapper .popup-tip.bad.hide"),
        "body errors are hidden by default"
      );
      assert.ok(
        exists(".d-editor-textarea-wrapper.disabled"),
        "textarea is disabled"
      );

      assert.ok(
        !exists("button.toggle-fullscreen"),
        "fullscreen button is not present"
      );

      const categoryChooser = selectKit(".category-chooser");

      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(2);

      assert.ok(
        !exists(".d-editor-textarea-wrapper.disabled"),
        "textarea is enabled"
      );

      await fillIn(".d-editor-input", "Now I can type stuff");
      await categoryChooser.expand();
      await categoryChooser.selectRowByIndex(0);

      assert.ok(
        !exists(".d-editor-textarea-wrapper.disabled"),
        "textarea is still enabled"
      );

      assert.ok(
        exists("button.toggle-fullscreen"),
        "fullscreen button is present"
      );
    });
  }
);

acceptance(
  "Composer enabled, uncategorized not allowed when topic_template not present",
  function (needs) {
    needs.user();
    needs.settings({ allow_uncategorized_topics: false });
    needs.site({
      categories: [
        {
          id: 1,
          name: "test won",
          slug: "test-won",
          permission: 1,
          topic_template: null,
        },
        {
          id: 2,
          name: "test too",
          slug: "test-too",
          permission: 1,
          topic_template: "",
        },
        {
          id: 3,
          name: "test free",
          slug: "test-free",
          permission: 1,
          topic_template: null,
        },
      ],
    });
    test("Enable composer/body if no topic templates present", async function (assert) {
      await visit("/");
      await click("#create-topic");
      assert.ok(exists(".d-editor-input"), "the composer input is visible");
      assert.ok(
        exists(".category-input .popup-tip.bad.hide"),
        "category errors are hidden by default"
      );
      assert.ok(
        !exists(".d-editor-textarea-wrapper.disabled"),
        "textarea is enabled"
      );

      assert.ok(
        exists("button.toggle-fullscreen"),
        "fullscreen button is present"
      );

      await click("#reply-control button.create");
      assert.ok(
        exists(".category-input .popup-tip.bad"),
        "it shows the choose a category error"
      );

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(1);

      assert.ok(
        !exists(".category-input .popup-tip.bad"),
        "category error removed after selecting category"
      );
    });
  }
);
