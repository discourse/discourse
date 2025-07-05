import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { testRenderedMarkdown } from "discourse/tests/helpers/rich-editor-helper";

module(
  "Integration | Component | prosemirror-editor - image extension",
  function (hooks) {
    setupRenderingTest(hooks);

    test(
      "basic image",
      testRenderedMarkdown(
        "![alt text](https://example.com/image.jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
        }
      )
    );

    test(
      "image with title",
      testRenderedMarkdown(
        '![alt text](https://example.com/image.jpg "title")',
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("title", "title");
        }
      )
    );

    test(
      "image with dimensions and title",
      testRenderedMarkdown(
        '![alt text|100x200](https://example.com/image.jpg "title")',
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("title", "title");
          assert.dom("img").hasAttribute("width", "100");
          assert.dom("img").hasAttribute("height", "200");
        }
      )
    );

    test(
      "image with dimensions and scale",
      testRenderedMarkdown(
        "![alt text|100x200, 50%](https://example.com/image.jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("width", "100");
          assert.dom("img").hasAttribute("height", "200");
          assert.dom("img").hasAttribute("data-scale", "50");

          // Check style attribute directly
          const img = document.querySelector("img");
          assert.strictEqual(
            img.style.width,
            "50px",
            "Image width style should be 50px"
          );
          assert.strictEqual(
            img.style.height,
            "100px",
            "Image height style should be 100px"
          );
        }
      )
    );

    test(
      "image with dimensions, scale and thumbnail",
      testRenderedMarkdown(
        "![alt text|100x200, 50%|thumbnail](https://example.com/image.jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image.jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
          assert.dom("img").hasAttribute("width", "100");
          assert.dom("img").hasAttribute("height", "200");
          assert.dom("img").hasAttribute("data-scale", "50");
          assert.dom("img").hasAttribute("data-thumbnail", "true");

          // Check style attribute directly
          const img = document.querySelector("img");
          assert.strictEqual(
            img.style.width,
            "50px",
            "Image width style should be 50px"
          );
          assert.strictEqual(
            img.style.height,
            "100px",
            "Image height style should be 100px"
          );
        }
      )
    );

    test(
      "image with parentheses in URL",
      testRenderedMarkdown(
        "![alt text](https://example.com/image\\(1\\).jpg)",
        (assert) => {
          assert.dom("img").exists("Image should exist");
          assert
            .dom("img")
            .hasAttribute("src", "https://example.com/image(1).jpg");
          assert.dom("img").hasAttribute("alt", "alt text");
        }
      )
    );

    test(
      "video placeholder",
      testRenderedMarkdown("![alt text|video](upload://hash)", (assert) => {
        assert
          .dom(".onebox-placeholder-container")
          .exists("Video placeholder should exist");
        assert
          .dom(".onebox-placeholder-container")
          .hasAttribute("data-orig-src", "upload://hash");
        assert
          .dom(".placeholder-icon.video")
          .exists("Video placeholder icon should exist");
      })
    );

    test(
      "audio element",
      testRenderedMarkdown("![alt text|audio](upload://hash)", (assert) => {
        assert.dom("audio").exists("Audio element should exist");
        assert.dom("audio").hasAttribute("preload", "metadata");
        assert.dom("audio source").exists("Audio source should exist");
        assert
          .dom("audio source")
          .hasAttribute("data-orig-src", "upload://hash");
      })
    );
  }
);
