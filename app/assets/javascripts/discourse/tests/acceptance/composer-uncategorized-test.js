import { click, fillIn, focus, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance(
  "Composer disabled, uncategorized not allowed when any topic_template present",
  function (needs) {
    needs.user({ whisperer: true });
    needs.settings({ allow_uncategorized_topics: false });

    test("Disable body until category is selected", async function (assert) {
      await visit("/");
      await click("#create-topic");
      assert.dom(".d-editor-input").exists("the composer input is visible");
      await focus(".title-input input");
      assert
        .dom(".title-input .popup-tip.good.hide")
        .exists("title errors are hidden by default");
      assert
        .dom(".d-editor-textarea-wrapper .popup-tip.bad.hide")
        .exists("body errors are hidden by default");
      assert
        .dom(".d-editor-textarea-wrapper.disabled")
        .exists("textarea is disabled");

      assert
        .dom("button.toggle-fullscreen")
        .doesNotExist("fullscreen button is not present");

      const categoryChooser = selectKit(".category-chooser");

      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(2);

      assert
        .dom(".d-editor-textarea-wrapper.disabled")
        .doesNotExist("textarea is enabled");

      await fillIn(".d-editor-input", "Now I can type stuff");
      await categoryChooser.expand();
      await categoryChooser.selectRowByIndex(0);

      assert
        .dom(".d-editor-textarea-wrapper.disabled")
        .doesNotExist("textarea is still enabled");

      assert
        .dom("button.toggle-fullscreen")
        .exists("fullscreen button is present");
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
      assert.dom(".d-editor-input").exists("the composer input is visible");
      assert
        .dom(".category-input .popup-tip.bad.hide")
        .exists("category errors are hidden by default");
      assert
        .dom(".d-editor-textarea-wrapper.disabled")
        .doesNotExist("textarea is enabled");

      assert
        .dom("button.toggle-fullscreen")
        .exists("fullscreen button is present");

      await click("#reply-control button.create");
      assert
        .dom(".category-input .popup-tip.bad")
        .exists("it shows the choose a category error");

      const categoryChooser = selectKit(".category-chooser");
      await categoryChooser.expand();
      await categoryChooser.selectRowByValue(1);

      assert
        .dom(".category-input .popup-tip.bad")
        .doesNotExist("category error removed after selecting category");
    });
  }
);
