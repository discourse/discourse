import { click, render, waitFor } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSettingUpload from "discourse/admin/components/site-settings/upload";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | site-settings/upload", function (hooks) {
  setupRenderingTest(hooks);

  test("with image file shows preview and lightbox", async function (assert) {
    const setting = { setting: "logo", placeholder: "/images/placeholder.png" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value="/images/logo.png"
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert.dom(".file-uploader").hasClass("has-file", "file present");
    assert.dom(".file-uploader").hasClass("has-image", "image file detected");
    assert.dom(".lightbox").exists("images can be expanded");
    assert.dom(".file-info").doesNotExist("images use preview, not file info");
    assert.dom(".d-icon-upload").exists("can replace file");
    assert.dom(".d-icon-trash-can").exists("can remove file");

    await click(".file-uploader-lightbox-btn");
    await waitFor(".pswp--open");
    assert.dom(".pswp").exists("lightbox opens on click");
  });

  test("with non-image file shows file info and download link", async function (assert) {
    const setting = {
      setting: "llms_txt",
      authorized_extensions: "txt",
      upload: {
        original_filename: "my-llms-file.txt",
        human_filesize: "4.68 KB",
      },
    };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value="/uploads/default/original/1X/abc123.txt"
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert.dom(".file-uploader").hasClass("has-file", "file present");
    assert.dom(".file-uploader").doesNotHaveClass("has-image", "not an image");
    assert
      .dom(".file-info")
      .exists("non-images show file details instead of preview");
    assert.dom(".file-icon").exists("visual indicator of file type");
    assert
      .dom(".file-name")
      .hasText("my-llms-file.txt", "displays original filename from metadata");
    assert.dom(".file-size").hasText("4.68 KB", "displays file size");
    assert.dom(".download-btn").exists("user can retrieve file contents");
    assert
      .dom(".download-btn")
      .hasAttribute(
        "download",
        "my-llms-file.txt",
        "triggers download vs navigation"
      );
    assert
      .dom(".download-btn")
      .hasAttribute("target", "_blank", "opens in new tab");
    assert
      .dom(".download-btn")
      .hasAttribute(
        "rel",
        "nofollow ugc noopener noreferrer",
        "security attributes present"
      );
    assert.dom(".lightbox").doesNotExist("no preview for non-images");
  });

  test("without file shows upload control", async function (assert) {
    const setting = { setting: "logo" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value=""
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert.dom(".file-uploader").hasClass("no-file", "empty state styling");
    assert.dom(".d-icon-upload").exists("can upload file");
    assert.dom(".d-icon-trash-can").doesNotExist("nothing to delete");
    assert.dom(".lightbox").doesNotExist("nothing to preview");
    assert.dom(".file-info").doesNotExist("no file to show info for");
  });

  test("with placeholder shows placeholder overlay", async function (assert) {
    const setting = { setting: "logo", placeholder: "/images/placeholder.png" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value=""
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".placeholder-overlay")
      .exists("shows default/example when empty");
  });

  test("accepts only images by default", async function (assert) {
    const setting = { setting: "logo" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value=""
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert
      .dom("[id$='__input']")
      .hasAttribute("accept", "image/*", "restricts to images for security");
  });

  test("uses authorized_extensions when specified", async function (assert) {
    const setting = { setting: "llms_txt", authorized_extensions: "txt|json" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value=""
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert
      .dom("[id$='__input']")
      .hasAttribute(
        "accept",
        ".txt,.json",
        "converts pipe-separated extensions to HTML accept format"
      );
  });

  test("delete button calls changeValueCallback with null", async function (assert) {
    const setting = { setting: "logo" };
    let callbackValue = "not called";
    this.set("handleChange", (value) => (callbackValue = value));

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value="/images/logo.png"
          @changeValueCallback={{this.handleChange}}
        />
      </template>
    );

    await click(".btn-danger");

    assert.strictEqual(callbackValue, null, "signals removal to parent");
  });

  test("shows upload restrictions when configured", async function (assert) {
    const setting = {
      setting: "llms_txt",
      authorized_extensions: "txt|json",
      max_file_size_kb: 512,
    };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value=""
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".file-uploader__restrictions")
      .exists("displays restrictions info when configured");
    assert
      .dom(".file-uploader__restrictions")
      .includesText(".txt", "shows accepted extensions");
    assert
      .dom(".file-uploader__restrictions")
      .includesText("512 KB", "shows max file size");
  });

  test("does not show restrictions for default image uploads", async function (assert) {
    const setting = { setting: "logo" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value=""
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".file-uploader__restrictions")
      .doesNotExist("no restrictions for standard image uploads");
  });

  test("applies background-size cover for welcome_banner_image", async function (assert) {
    const setting = { setting: "welcome_banner_image" };

    await render(
      <template>
        <SiteSettingUpload
          @setting={{setting}}
          @value="/images/banner.png"
          @changeValueCallback={{this.noop}}
        />
      </template>
    );

    assert
      .dom(".file-uploader__preview")
      .hasClass("--bg-size-cover", "banner images use cover sizing");
  });
});
