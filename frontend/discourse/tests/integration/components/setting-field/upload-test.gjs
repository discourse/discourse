import { click, render, waitFor } from "@ember/test-helpers";
import "discourse/admin/lib/setting-field-types";
import { module, test } from "qunit";
import Form from "discourse/components/form";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

const LOGO = { key: "logo", type: "upload", label: "Upload" };

function renderUpload(definition, value, onSet) {
  const data = { [definition.key]: value };

  return render(
    <template>
      <Form @data={{data}} @onSet={{onSet}} as |form|>
        <SettingDefinitionField @definition={{definition}} @form={{form}} />
      </Form>
    </template>
  );
}

module("Integration | Component | SettingField | Upload", function (hooks) {
  setupRenderingTest(hooks);

  test("with image file shows preview and lightbox", async function (assert) {
    await renderUpload(LOGO, "/images/logo.png");

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
    const definition = {
      key: "llms_txt",
      type: "upload",
      label: "Upload",
      authorized_extensions: "txt",
      upload: {
        original_filename: "my-llms-file.txt",
        human_filesize: "4.68 KB",
      },
    };

    await renderUpload(definition, "/uploads/default/original/1X/abc123.txt");

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
    await renderUpload(LOGO, "");

    assert.dom(".file-uploader").hasClass("no-file", "empty state styling");
    assert.dom(".d-icon-upload").exists("can upload file");
    assert.dom(".d-icon-trash-can").doesNotExist("nothing to delete");
    assert.dom(".lightbox").doesNotExist("nothing to preview");
    assert.dom(".file-info").doesNotExist("no file to show info for");
    assert
      .dom("[id$='__input']")
      .hasAttribute("accept", "image/*", "restricts to images for security");
    assert
      .dom(".file-uploader__restrictions")
      .doesNotExist("no restrictions for standard image uploads");
  });

  test("delete button sets the field to null", async function (assert) {
    let callbackValue = "not called";
    const handleChange = (_name, value) => (callbackValue = value);

    await renderUpload(LOGO, "/images/logo.png", handleChange);

    await click(".btn-danger");

    assert.strictEqual(callbackValue, null, "signals removal to parent");
  });

  test("shows upload restrictions when configured", async function (assert) {
    const definition = {
      key: "llms_txt",
      type: "upload",
      label: "Upload",
      authorized_extensions: "txt|json",
      max_file_size_kb: 512,
    };

    await renderUpload(definition, "");

    assert
      .dom("[id$='__input']")
      .hasAttribute(
        "accept",
        ".txt,.json",
        "converts pipe-separated extensions to HTML accept format"
      );
    assert
      .dom(".file-uploader__restrictions")
      .includesText(".txt", "shows accepted extensions");
    assert
      .dom(".file-uploader__restrictions")
      .includesText("512 KB", "shows max file size");
  });

  test("applies background-size cover for welcome_banner_image", async function (assert) {
    const definition = {
      key: "welcome_banner_image",
      type: "upload",
      label: "Upload",
    };

    await renderUpload(definition, "/images/banner.png");

    assert
      .dom(".file-uploader__preview")
      .hasClass("--bg-size-cover", "banner images use cover sizing");
  });
});
