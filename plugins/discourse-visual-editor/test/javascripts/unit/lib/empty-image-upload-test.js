import { module, test } from "qunit";
import { entryHasEmptyImageUploadArgs } from "discourse/plugins/discourse-visual-editor/discourse/lib/empty-image-upload";

const IMAGE_UPLOAD_SCHEMA = {
  image: {
    type: "object",
    ui: { control: "image-upload", label: "Image" },
  },
  imageDark: {
    type: "object",
    ui: { control: "image-upload", label: "Dark variant" },
  },
  alt: { type: "string", ui: { label: "Alt text" } },
};

module("Unit | Visual Editor | entryHasEmptyImageUploadArgs", function () {
  test("returns false when the schema has no image-upload args", function (assert) {
    const schema = { title: { type: "string", ui: { label: "Title" } } };
    assert.false(entryHasEmptyImageUploadArgs(schema, {}));
  });

  test("returns true when every image-upload arg is missing", function (assert) {
    assert.true(entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, {}));
  });

  test("returns true when image-upload args are explicitly nullish", function (assert) {
    assert.true(
      entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, {
        image: null,
        imageDark: undefined,
      })
    );
  });

  test("returns true when image-upload args are objects with no url", function (assert) {
    assert.true(
      entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, {
        image: { width: 400, height: 300 },
      })
    );
  });

  test("returns false as soon as one image-upload arg has a url", function (assert) {
    assert.false(
      entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, {
        image: { url: "/uploads/cat.png", width: 100, height: 100 },
      })
    );
  });

  test("returns false when the dark variant alone is set", function (assert) {
    assert.false(
      entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, {
        imageDark: { url: "/uploads/cat-dark.png" },
      })
    );
  });

  test("ignores args whose ui.control is not image-upload", function (assert) {
    const schema = {
      avatarUrl: { type: "string", ui: { control: "url", label: "URL" } },
      backgroundColor: {
        type: "string",
        ui: { control: "color", label: "Color" },
      },
    };
    assert.false(entryHasEmptyImageUploadArgs(schema, {}));
  });

  test("returns false when the schema is null/undefined", function (assert) {
    assert.false(entryHasEmptyImageUploadArgs(null, {}));
    assert.false(entryHasEmptyImageUploadArgs(undefined, {}));
  });

  test("tolerates a missing live-args object", function (assert) {
    assert.true(entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, null));
    assert.true(entryHasEmptyImageUploadArgs(IMAGE_UPLOAD_SCHEMA, undefined));
  });
});
