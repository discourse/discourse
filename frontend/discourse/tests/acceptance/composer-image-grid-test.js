import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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

    assert
      .dom(".d-editor-input")
      .hasValue(
        `[grid]\n${uploads.join("\n")}\n[/grid]`,
        "Image grid toggles on"
      );

    await click(
      ".button-wrapper[data-image-index='0'] .wrap-image-grid-button"
    );

    assert
      .dom(".d-editor-input")
      .hasValue(uploads.join("\n"), "Image grid toggles off");

    const multipleImages = `![zorro|10x10](upload://zorro.png) ![z2|20x20](upload://zorrito.png)\nand a second group of images\n\n${uploads.join(
      "\n"
    )}`;
    await fillIn(".d-editor-input", multipleImages);

    await click(".image-wrapper:first-child .wrap-image-grid-button");

    assert.dom(".d-editor-input").hasValue(
      `[grid]![zorro|10x10](upload://zorro.png) ![z2|20x20](upload://zorrito.png)[/grid]
and a second group of images

![image_example_0|666x500](upload://q4iRxcuSAzfnbUaCsbjMXcGrpaK.jpeg)
![image_example_1|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)
![image_example_3|481x480](upload://p1ijebM2iyQcUswBffKwMny3gxu.jpeg)`,
      "First image grid toggles on"
    );

    await click(".image-wrapper:nth-of-type(1) .wrap-image-grid-button");

    assert
      .dom(".d-editor-input")
      .hasValue(multipleImages, "First image grid toggles off");

    // Second group of images is in paragraph 2
    assert
      .dom(".d-editor-preview p:nth-child(2) .wrap-image-grid-button")
      .hasAttribute(
        "data-image-count",
        "3",
        "Grid button has correct image count"
      );

    await click(".d-editor-preview p:nth-child(2) .wrap-image-grid-button");

    assert.dom(".d-editor-input").hasValue(
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

  test("Grid button counts only images in the same block", async function (assert) {
    await visit("/");
    await click("#create-topic");

    await fillIn(
      ".d-editor-input",
      `- ![outer|10x10](upload://outer.png)\n  - ![nested|20x20](upload://nested.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .doesNotExist("a nested list item is a block of its own");

    await fillIn(
      ".d-editor-input",
      `- ![first|10x10](upload://first.png) ![second|20x20](upload://second.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .hasAttribute("data-image-count", "2", "two images share the list item");

    await fillIn(
      ".d-editor-input",
      `- ![outer|10x10](upload://outer.png)\n  # ![heading|20x20](upload://heading.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .doesNotExist("a heading is a block of its own");

    await fillIn(
      ".d-editor-input",
      `# ![first|10x10](upload://first.png) ![second|20x20](upload://second.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .hasAttribute("data-image-count", "2", "two images share the heading");

    await fillIn(
      ".d-editor-input",
      `- ![outer|10x10](upload://outer.png)\n  # Heading\n  ![after|20x20](upload://after.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .doesNotExist("a heading in between ends the run");

    await fillIn(
      ".d-editor-input",
      `- ![first|10x10](upload://first.png) ![second|20x20](upload://second.png)\n  # Heading\n  ![after|20x20](upload://after.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .hasAttribute("data-image-count", "2", "the run stops at the heading");

    await fillIn(
      ".d-editor-input",
      `- ![first|10x10](upload://first.png) <span>\n  # ![inner|20x20](upload://inner.png)\n  </span> ![last|30x30](upload://last.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .doesNotExist("an inline wrapper holding a block ends the run");

    await fillIn(
      ".d-editor-input",
      `- <!-- a comment -->\n  ![first|10x10](upload://first.png) ![second|20x20](upload://second.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .hasAttribute("data-image-count", "2", "a comment does not open a block");

    await fillIn(
      ".d-editor-input",
      `![first|10x10](upload://first.png)<script>![gone|20x20](upload://gone.png)</script>![last|30x30](upload://last.png)`
    );

    assert
      .dom(".wrap-image-grid-button")
      .hasAttribute(
        "data-image-count",
        "3",
        "the count follows the markdown, not the sanitized preview"
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
