import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";

acceptance("Composer - Image Grid", function (needs) {
  needs.user();
  needs.settings({
    allow_uncategorized_topics: true,
  });

  needs.pretender((server, helper) => {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([]);
    });
  });

  test("Image Grid", async function (assert) {
    await visit("/");

    const uploads = [
      "![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)",
      "![image_example_1|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)",
      "![image_example_3|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)",
    ];

    await click("#create-topic");
    await fillIn(".d-editor-input", uploads.join("\n"));

    await click(
      ".button-wrapper[data-image-index='0'] .wrap-image-grid-button"
    );

    assert.strictEqual(
      query(".d-editor-input").value,
      `[grid]\n${uploads.join("\n")}\n[/grid]`,
      "Image grid toggles on"
    );

    await click(
      ".button-wrapper[data-image-index='0'] .wrap-image-grid-button"
    );

    assert.strictEqual(
      query(".d-editor-input").value,
      uploads.join("\n"),
      "Image grid toggles off"
    );

    const multipleImages = `![zorro|10x10](upload://zorro.png) ![z2|20x20](upload://zorrito.png)\nand a second group of images\n\n${uploads.join(
      "\n"
    )}`;
    await fillIn(".d-editor-input", multipleImages);

    await click(".image-wrapper:first-child .wrap-image-grid-button");

    assert.strictEqual(
      query(".d-editor-input").value,
      `[grid]![zorro|10x10](upload://zorro.png) ![z2|20x20](upload://zorrito.png)[/grid]
and a second group of images

![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)
![image_example_1|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)
![image_example_3|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)`,
      "First image grid toggles on"
    );

    await click(".image-wrapper:nth-of-type(1) .wrap-image-grid-button");

    assert.strictEqual(
      query(".d-editor-input").value,
      multipleImages,
      "First image grid toggles off"
    );

    // Second group of images is in paragraph 2
    assert
      .dom(".d-editor-preview p:nth-child(2) .wrap-image-grid-button")
      .hasAttribute(
        "data-image-count",
        "3",
        "Grid button has correct image count"
      );

    await click(".d-editor-preview p:nth-child(2) .wrap-image-grid-button");

    assert.strictEqual(
      query(".d-editor-input").value,
      `![zorro|10x10](upload://zorro.png) ![z2|20x20](upload://zorrito.png)
and a second group of images

[grid]
![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)
![image_example_1|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)
![image_example_3|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)
[/grid]`,
      "Second image grid toggles on"
    );
  });

  test("Image Grid Preview", async function (assert) {
    await visit("/");

    const uploads = [
      "![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)",
      "![image_example_1|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)",
    ];

    await click("#create-topic");
    await fillIn(".d-editor-input", uploads.join("\n"));

    assert
      .dom(".image-wrapper:first-child .wrap-image-grid-button")
      .hasAttribute(
        "data-image-count",
        "2",
        "Grid button has correct image count"
      );

    await click(
      ".button-wrapper[data-image-index='0'] .wrap-image-grid-button"
    );

    assert.strictEqual(
      document.querySelectorAll(".d-editor-preview .d-image-grid-column")
        .length,
      2,
      "Preview organizes images into two columns"
    );

    await fillIn(".d-editor-input", `[grid]\n${uploads[0]}\n[/grid]`);

    assert
      .dom(".d-editor-preview .d-image-grid")
      .hasAttribute(
        "data-disabled",
        "true",
        "Grid is disabled when there is only one image"
      );

    await fillIn(
      ".d-editor-input",
      `[grid]${uploads[0]} ${uploads[1]} ${uploads[0]} ${uploads[1]}[/grid]`
    );

    assert.strictEqual(
      document.querySelectorAll(".d-editor-preview .d-image-grid-column")
        .length,
      2,
      "Special case of two columns for 4 images"
    );
  });
});
