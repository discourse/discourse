import { module, test } from "qunit";
import {
  EXTERNAL_IMAGE_DROP_SOURCE,
  firstImageFile,
} from "discourse/plugins/discourse-wireframe/discourse/lib/external-image-drop";

function fileOf(type) {
  return new File(["x"], "f", { type });
}

module("Unit | Wireframe | external-image-drop", function () {
  module("EXTERNAL_IMAGE_DROP_SOURCE", function () {
    test("mirrors a palette image-block drag", function (assert) {
      assert.strictEqual(EXTERNAL_IMAGE_DROP_SOURCE.type, "wf-palette-block");
      assert.strictEqual(EXTERNAL_IMAGE_DROP_SOURCE.data.blockName, "image");
      assert.deepEqual(EXTERNAL_IMAGE_DROP_SOURCE.data.defaultArgs, {});
    });

    test("is frozen so descriptor builders can't mutate the shared source", function (assert) {
      assert.true(Object.isFrozen(EXTERNAL_IMAGE_DROP_SOURCE));
      assert.true(Object.isFrozen(EXTERNAL_IMAGE_DROP_SOURCE.data));
    });
  });

  module("firstImageFile", function () {
    test("returns the only image file", function (assert) {
      const png = fileOf("image/png");
      assert.strictEqual(firstImageFile([png]), png);
    });

    test("skips non-image files and returns the first image", function (assert) {
      const pdf = fileOf("application/pdf");
      const jpg = fileOf("image/jpeg");
      assert.strictEqual(firstImageFile([pdf, jpg]), jpg);
    });

    test("returns null when no file is an image", function (assert) {
      assert.strictEqual(firstImageFile([fileOf("application/pdf")]), null);
    });

    test("returns null for empty or nullish input", function (assert) {
      assert.strictEqual(firstImageFile([]), null);
      assert.strictEqual(firstImageFile(null), null);
      assert.strictEqual(firstImageFile(undefined), null);
    });

    test("tolerates files without a type", function (assert) {
      const typeless = new File(["x"], "f");
      const jpg = fileOf("image/jpeg");
      assert.strictEqual(firstImageFile([typeless, jpg]), jpg);
    });
  });
});
