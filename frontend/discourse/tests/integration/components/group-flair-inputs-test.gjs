import EmberObject from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import GroupFlairInputs from "discourse/components/group-flair-inputs";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";

module("Integration | Component | GroupFlairInputs", function (hooks) {
  setupRenderingTest(hooks);

  test("follows the chosen flair type", async function (assert) {
    const model = EmberObject.create({ name: "staff", flair_type: "icon" });

    await render(<template><GroupFlairInputs @model={{model}} /></template>);

    assert
      .dom(".group-flair-inputs")
      .includesText(i18n("groups.flair_preview_icon"));
    assert.dom("#group-flair-uploader").doesNotExist();

    await click("#avatar-flair-image");

    assert.strictEqual(model.flair_type, "image", "writes the type");
    assert.dom("#group-flair-uploader").exists("offers the image upload");
    assert
      .dom(".group-flair-inputs")
      .includesText(
        i18n("groups.flair_preview_image"),
        "labels the preview for the image"
      );
  });
});
