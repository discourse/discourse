import { click, fillIn, triggerKeyEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Image Preview", function (needs) {
  needs.user({});
  needs.settings({ allow_uncategorized_topics: true });
  needs.site({ can_tag_topics: true });
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
    server.get("/posts/419", () => {
      return helper.response({ id: 419 });
    });
    server.get("/composer/mentions", () => {
      return helper.response({
        users: [],
        user_reasons: {},
        groups: { staff: { user_count: 30 } },
        group_reasons: {},
        max_users_notified_per_group_mention: 100,
      });
    });
  });

  const assertImageResized = (assert, uploads) => {
    assert
      .dom(".d-editor-input")
      .hasValue(uploads.join("\n"), "resizes uploaded image");
  };

  test("Image resizing buttons", async function (assert) {
    await visit("/");
    await click("#create-topic");

    let uploads = [
      // 0 Default markdown with dimensions- should work
      "<a href='https://example.com'>![test|690x313](upload://test.png)</a>",
      // 1 Image with scaling percentage, should work
      "![test|690x313,50%](upload://test.png)",
      // 2 image with scaling percentage and a proceeding whitespace, should work
      "![test|690x313, 50%](upload://test.png)",
      // 3 No dimensions, should not work
      "![test](upload://test.jpeg)",
      // 4 Wrapped in backticks should not work
      "`![test|690x313](upload://test.png)`",
      // 5 html image - should not work
      "<img src='/images/avatar.png' wight='20' height='20'>",
      // 6 two images one the same line, but both are syntactically correct - both should work
      "![onTheSameLine1|200x200](upload://onTheSameLine1.jpeg) ![onTheSameLine2|250x250](upload://onTheSameLine2.jpeg)",
      // 7 & 8 Identical images - both should work
      "![identicalImage|300x300](upload://identicalImage.png)",
      "![identicalImage|300x300](upload://identicalImage.png)",
      // 9 Image with whitespaces in alt - should work
      "![image with spaces in alt|690x220](upload://test.png)",
      // 10 Image with markdown title - should work
      `![image|690x220](upload://test.png "image title")`,
      // 11 bbcode - should not work
      "[img]/images/avatar.png[/img]",
      // 12 Image with data attributes
      "![test|foo=bar|690x313,50%|bar=baz](upload://test.png)",
    ];

    await fillIn(".d-editor-input", uploads.join("\n"));

    assert
      .dom(".button-wrapper")
      .exists({ count: 10 }, "adds correct number of scaling button groups");

    // Default
    uploads[0] =
      "<a href='https://example.com'>![test|690x313, 50%](upload://test.png)</a>";
    await click(
      ".button-wrapper[data-image-index='0'] .scale-btn[data-scale='50']"
    );
    assertImageResized(assert, uploads);

    // Targets the correct image if two on the same line
    uploads[6] =
      "![onTheSameLine1|200x200, 50%](upload://onTheSameLine1.jpeg) ![onTheSameLine2|250x250](upload://onTheSameLine2.jpeg)";
    await click(
      ".button-wrapper[data-image-index='3'] .scale-btn[data-scale='50']"
    );
    assertImageResized(assert, uploads);

    // Try the other image on the same line
    uploads[6] =
      "![onTheSameLine1|200x200, 50%](upload://onTheSameLine1.jpeg) ![onTheSameLine2|250x250, 75%](upload://onTheSameLine2.jpeg)";
    await click(
      ".button-wrapper[data-image-index='4'] .scale-btn[data-scale='75']"
    );
    assertImageResized(assert, uploads);

    // Make sure we target the correct image if there are duplicates
    uploads[7] = "![identicalImage|300x300, 50%](upload://identicalImage.png)";
    await click(
      ".button-wrapper[data-image-index='5'] .scale-btn[data-scale='50']"
    );
    assertImageResized(assert, uploads);

    // Try the other dupe
    uploads[8] = "![identicalImage|300x300, 75%](upload://identicalImage.png)";
    await click(
      ".button-wrapper[data-image-index='6'] .scale-btn[data-scale='75']"
    );
    assertImageResized(assert, uploads);

    // Don't mess with image titles
    uploads[10] = `![image|690x220, 75%](upload://test.png "image title")`;
    await click(
      ".button-wrapper[data-image-index='8'] .scale-btn[data-scale='75']"
    );
    assertImageResized(assert, uploads);

    // Keep data attributes
    uploads[12] = `![test|foo=bar|690x313, 75%|bar=baz](upload://test.png)`;
    await click(
      ".button-wrapper[data-image-index='9'] .scale-btn[data-scale='75']"
    );
    assertImageResized(assert, uploads);

    await fillIn(
      ".d-editor-input",
      `
![test|690x313](upload://test.png)

\`<script>alert("xss")</script>\`
    `
    );

    // don't add controls to video uploads with dimensions in name
    await fillIn(
      ".d-editor-input",
      "![SampleVideo_1280x720|video](upload://test.mp4)"
    );
    assert.dom(".button-wrapper").doesNotExist();

    assert
      .dom("script")
      .doesNotExist("it does not unescape script tags in code blocks");
  });

  test("Editing alt text (with enter key) for single image in preview updates alt text in composer", async function (assert) {
    const scaleButtonContainer = ".scale-btn-container";

    const editAltTextButton = ".alt-text-edit-btn";

    const altTextEditOk = ".alt-text-edit-ok";
    const altTextEditCancel = ".alt-text-edit-cancel";

    await visit("/");

    await click("#create-topic");
    await fillIn(".d-editor-input", `![zorro|200x200](upload://zorro.png)`);

    assert.dom(".alt-text").hasText("zorro", "correct alt text");
    assert.dom(".alt-text").isVisible("alt text is visible");
    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(".alt-text-input").isNotVisible("alt text input is hidden");
    assert.dom(altTextEditOk).isNotVisible("alt text edit ok button is hidden");
    assert
      .dom(altTextEditCancel)
      .isNotVisible("alt text edit cancel is hidden");

    await click(editAltTextButton);

    assert.dom(scaleButtonContainer).isNotVisible("scale buttons are hidden");
    assert.dom(".alt-text").isNotVisible("alt text is hidden");
    assert
      .dom(editAltTextButton)
      .isNotVisible("alt text edit button is hidden");
    assert.dom(".alt-text-input").isVisible("alt text input is visible");
    assert.dom(altTextEditOk).isVisible("alt text edit ok button is visible");
    assert.dom(altTextEditCancel).isVisible("alt text edit cancel is hidden");
    assert
      .dom(".alt-text-input")
      .hasValue("zorro", "correct alt text in input");

    await triggerKeyEvent(".alt-text-input", "keypress", "[");
    await triggerKeyEvent(".alt-text-input", "keypress", "]");
    assert.dom(".alt-text-input").hasValue("zorro", "does not input [ ] keys");

    await fillIn(".alt-text-input", "steak");
    await triggerKeyEvent(".alt-text-input", "keypress", 13);

    assert
      .dom(".d-editor-input")
      .hasValue("![steak|200x200](upload://zorro.png)", "alt text updated");
    assert.dom(".alt-text").hasText("steak", "shows the alt text");
    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(scaleButtonContainer).isVisible("scale buttons are visible");
    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(".alt-text-input").isNotVisible("alt text input is hidden");
    assert.dom(altTextEditOk).isNotVisible("alt text edit ok button is hidden");
    assert
      .dom(altTextEditCancel)
      .isNotVisible("alt text edit cancel is hidden");
  });

  test("Editing alt text (with check button) in preview updates alt text in composer", async function (assert) {
    const scaleButtonContainer = ".scale-btn-container";
    const editAltTextButton = ".alt-text-edit-btn";

    const altTextInput = ".alt-text-input";
    const altTextEditOk = ".alt-text-edit-ok";
    const altTextEditCancel = ".alt-text-edit-cancel";

    await visit("/");

    await click("#create-topic");
    await fillIn(".d-editor-input", `![zorro|200x200](upload://zorro.png)`);

    await click(editAltTextButton);

    await fillIn(altTextInput, "steak");
    await click(altTextEditOk);

    assert
      .dom(".d-editor-input")
      .hasValue("![steak|200x200](upload://zorro.png)", "alt text updated");
    assert.dom(".alt-text").hasText("steak", "shows the alt text");

    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(scaleButtonContainer).isVisible("scale buttons are visible");
    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(altTextInput).isNotVisible("alt text input is hidden");
    assert.dom(altTextEditOk).isNotVisible("alt text edit ok button is hidden");
    assert
      .dom(altTextEditCancel)
      .isNotVisible("alt text edit cancel is hidden");
  });

  test("Cancel alt text edit in preview does not update alt text in composer", async function (assert) {
    const scaleButtonContainer = ".scale-btn-container";

    const editAltTextButton = ".alt-text-edit-btn";

    const altTextInput = ".alt-text-input";
    const altTextEditOk = ".alt-text-edit-ok";
    const altTextEditCancel = ".alt-text-edit-cancel";

    await visit("/");

    await click("#create-topic");
    await fillIn(".d-editor-input", `![zorro|200x200](upload://zorro.png)`);

    await click(editAltTextButton);

    await fillIn(altTextInput, "steak");
    await click(altTextEditCancel);

    assert
      .dom(".d-editor-input")
      .hasValue("![zorro|200x200](upload://zorro.png)", "alt text not updated");
    assert.dom(".alt-text").hasText("zorro", "shows the unedited alt text");

    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(scaleButtonContainer).isVisible("scale buttons are visible");
    assert.dom(editAltTextButton).isVisible("alt text edit button is visible");
    assert.dom(altTextInput).isNotVisible("alt text input is hidden");
    assert.dom(altTextEditOk).isNotVisible("alt text edit ok button is hidden");
    assert
      .dom(altTextEditCancel)
      .isNotVisible("alt text edit cancel is hidden");
  });

  test("Editing alt text for one of two images in preview updates correct alt text in composer", async function (assert) {
    const editAltTextButton = ".alt-text-edit-btn";
    const altTextInput = ".alt-text-input";

    await visit("/");
    await click("#create-topic");

    await fillIn(
      ".d-editor-input",
      `![zorro|200x200](upload://zorro.png) ![not-zorro|200x200](upload://not-zorro.png)`
    );
    await click(editAltTextButton);

    await fillIn(altTextInput, "tomtom");
    await triggerKeyEvent(altTextInput, "keypress", "Enter");

    assert
      .dom(".d-editor-input")
      .hasValue(
        `![tomtom|200x200](upload://zorro.png) ![not-zorro|200x200](upload://not-zorro.png)`,
        "the correct image's alt text updated"
      );
  });

  test("Deleting alt text for image empties alt text in composer and allows further modification", async function (assert) {
    const editAltTextButton = ".alt-text-edit-btn";
    const altTextInput = ".alt-text-input";

    await visit("/");

    await click("#create-topic");
    await fillIn(".d-editor-input", `![zorro|200x200](upload://zorro.png)`);

    await click(editAltTextButton);

    await fillIn(altTextInput, "");
    await triggerKeyEvent(altTextInput, "keypress", "Enter");

    assert
      .dom(".d-editor-input")
      .hasValue("![|200x200](upload://zorro.png)", "alt text updated");
    assert.dom(".alt-text").hasText("", "shows the alt text");

    await click(editAltTextButton);

    await fillIn(altTextInput, "tomtom");
    await triggerKeyEvent(altTextInput, "keypress", "Enter");

    assert
      .dom(".d-editor-input")
      .hasValue("![tomtom|200x200](upload://zorro.png)", "alt text updated");
  });

  test("Image delete button", async function (assert) {
    await visit("/");
    await click("#create-topic");

    let uploads = [
      "![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)",
      "![image_example_1|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)",
    ];

    await fillIn(".d-editor-input", uploads.join("\n"));

    uploads[0] = ""; // delete the first image.

    //click on the remove button of the first image
    await click(".button-wrapper[data-image-index='0'] .delete-image-button");

    assert
      .dom(".d-editor-input")
      .hasValue(uploads.join("\n"), "Image should be removed from the editor");

    assert
      .dom(".d-editor-input")
      .doesNotIncludeValue("image_example_0", "does not have the first image");

    assert
      .dom(".d-editor-input")
      .hasValue(/image_example_1/, "has the second image");
  });
});

acceptance("Composer - Image Preview - Plugin API", function (needs) {
  needs.user({});
  needs.settings({ allow_uncategorized_topics: true });
  needs.site({ can_tag_topics: true });
  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  });

  needs.hooks.beforeEach(() => {
    withPluginApi((api) => {
      api.addComposerImageWrapperButton(
        "My Custom Button",
        "custom-button-class",
        "lock",
        async (event) => {
          if (event.target.classList.contains("custom-button-class")) {
            await fillIn(".d-editor-input", "custom button change");
          }
        }
      );
    });
  });

  test("image wrapper includes extra API button and is functional", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn(
      ".d-editor-input",
      "![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)"
    );

    assert
      .dom(".image-wrapper .custom-button-class")
      .exists("The custom button is added to the image preview wrapper");

    await click(".custom-button-class");

    assert
      .dom(".d-editor-input")
      .hasValue(
        "custom button change",
        "The custom button changes the editor input"
      );
  });
});

acceptance(
  "Composer - Image Preview - Plugin API - includeCondition",
  function (needs) {
    needs.user({});
    needs.settings({ allow_uncategorized_topics: true });
    needs.site({ can_tag_topics: true });
    needs.pretender((server, helper) => {
      server.post("/uploads/lookup-urls", () => {
        return helper.response([]);
      });
    });

    needs.hooks.beforeEach(() => {
      withPluginApi((api) => {
        // Button that only shows for JPEG images
        api.addComposerImageWrapperButton(
          "JPEG Only",
          "jpeg-only-button",
          "image",
          () => {},
          (uploadUrl) => uploadUrl && uploadUrl.endsWith(".jpeg")
        );

        // Button that only shows for SVG images
        api.addComposerImageWrapperButton(
          "SVG Only",
          "svg-only-button",
          "file",
          () => {},
          (uploadUrl) => uploadUrl && uploadUrl.endsWith(".svg")
        );

        // Button without condition that should show for all images
        api.addComposerImageWrapperButton(
          "Always Show",
          "always-show-button",
          "check",
          () => {}
        );
      });
    });

    test("buttons with includeCondition only show for matching image types", async function (assert) {
      await visit("/");
      await click("#create-topic");

      // Add a JPEG image
      await fillIn(
        ".d-editor-input",
        "![jpeg-image|666x500](upload://abc123.jpeg)"
      );

      assert
        .dom(".image-wrapper .jpeg-only-button")
        .exists("JPEG button appears for JPEG image");

      assert
        .dom(".image-wrapper .svg-only-button")
        .doesNotExist("SVG button does not appear for JPEG image");

      // Replace with an SVG image
      await fillIn(
        ".d-editor-input",
        "![svg-image|666x500](upload://xyz789.svg)"
      );

      assert
        .dom(".image-wrapper .svg-only-button")
        .exists("SVG button appears for SVG image");

      assert
        .dom(".image-wrapper .jpeg-only-button")
        .doesNotExist("JPEG button does not appear for SVG image");
    });

    test("button without includeCondition shows for all images", async function (assert) {
      await visit("/");
      await click("#create-topic");

      // Test with JPEG
      await fillIn(
        ".d-editor-input",
        "![jpeg-image|666x500](upload://abc123.jpeg)"
      );

      assert
        .dom(".image-wrapper .always-show-button")
        .exists("Button without condition appears for JPEG");

      // Test with SVG
      await fillIn(
        ".d-editor-input",
        "![svg-image|666x500](upload://xyz789.svg)"
      );

      assert
        .dom(".image-wrapper .always-show-button")
        .exists("Button without condition appears for SVG");
    });
  }
);
