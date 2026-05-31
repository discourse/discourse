import { module, test } from "qunit";
import {
  entryHasOnlyEmptyImageArgs,
  imageArgEntries,
  isImageArgValueEmpty,
} from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";

const IMAGE_SCHEMA = {
  image: { type: "image", allowDark: true },
  avatar: { type: "image", allowDark: false },
  alt: { type: "string" },
};

module("Unit | Wireframe | image-arg primitives", function () {
  module("imageArgEntries", function () {
    test("returns nothing when the schema has no image args", function (assert) {
      const schema = { title: { type: "string" } };
      assert.deepEqual(imageArgEntries(schema, {}), []);
    });

    test("lists each image arg with its emptiness flag", function (assert) {
      const entries = imageArgEntries(IMAGE_SCHEMA, {
        image: { url: "/uploads/cover.png", width: 400, height: 300 },
      });
      assert.deepEqual(
        entries.map((e) => e.name),
        ["image", "avatar"],
        "image args are returned in declaration order"
      );
      assert.false(entries[0].isEmpty, "filled image is reported as non-empty");
      assert.true(entries[1].isEmpty, "missing avatar is reported as empty");
    });

    test("treats nullish values as empty", function (assert) {
      const entries = imageArgEntries(IMAGE_SCHEMA, {
        image: null,
        avatar: undefined,
      });
      assert.true(entries.every((e) => e.isEmpty));
    });

    test("treats objects without a url as empty", function (assert) {
      const entries = imageArgEntries(IMAGE_SCHEMA, {
        image: { width: 400, height: 300 },
      });
      assert.true(entries[0].isEmpty);
    });

    test("tolerates a missing args object", function (assert) {
      const entries = imageArgEntries(IMAGE_SCHEMA, null);
      assert.true(entries.every((e) => e.isEmpty));
    });

    test("tolerates a null/undefined schema", function (assert) {
      assert.deepEqual(imageArgEntries(null, {}), []);
      assert.deepEqual(imageArgEntries(undefined, {}), []);
    });

    test("ignores args that are not type: image", function (assert) {
      const schema = {
        avatarUrl: { type: "string", ui: { control: "url" } },
        legacy: {
          type: "object",
          ui: { control: "image-upload" },
        },
      };
      assert.deepEqual(imageArgEntries(schema, {}), []);
    });
  });

  module("isImageArgValueEmpty", function () {
    test("returns true for nullish", function (assert) {
      assert.true(isImageArgValueEmpty(null));
      assert.true(isImageArgValueEmpty(undefined));
    });

    test("returns true for objects with no url", function (assert) {
      assert.true(isImageArgValueEmpty({ width: 100 }));
      assert.true(isImageArgValueEmpty({ url: "" }));
    });

    test("returns false for a value with a non-empty url", function (assert) {
      assert.false(isImageArgValueEmpty({ url: "/uploads/cat.png" }));
    });
  });

  module("entryHasOnlyEmptyImageArgs", function () {
    test("returns false when the schema has no image args", function (assert) {
      assert.false(
        entryHasOnlyEmptyImageArgs({ title: { type: "string" } }, {})
      );
    });

    test("returns true when every image arg is empty", function (assert) {
      assert.true(entryHasOnlyEmptyImageArgs(IMAGE_SCHEMA, {}));
    });

    test("returns false as soon as one image arg is filled", function (assert) {
      assert.false(
        entryHasOnlyEmptyImageArgs(IMAGE_SCHEMA, {
          image: { url: "/uploads/cover.png" },
        })
      );
    });
  });
});
