import Component from "@glimmer/component";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import { getBlockDisplayMetadata } from "discourse/lib/blocks/-internals/display-metadata";

module("Unit | Lib | blocks/display-metadata", function () {
  test("returns null for components that aren't blocks", function (assert) {
    class NotABlock {}
    assert.strictEqual(getBlockDisplayMetadata(NotABlock), null);
  });

  test("returns explicit values when the block sets them", function (assert) {
    @block("display-explicit", {
      displayName: "Hero Banner",
      icon: "image",
      category: "Content",
      previewArgs: { title: "Sample" },
      thumbnail: "/uploads/preview.png",
    })
    class ExplicitBlock extends Component {}

    assert.deepEqual(getBlockDisplayMetadata(ExplicitBlock), {
      displayName: "Hero Banner",
      icon: "image",
      category: "Content",
      previewArgs: { title: "Sample" },
      thumbnail: "/uploads/preview.png",
      paletteHidden: false,
      transparent: false,
    });
  });

  test("falls back to Title Case shortName for displayName", function (assert) {
    @block("display-default-single")
    class SingleBlock extends Component {}

    @block("display-default-multi-word")
    class MultiWordBlock extends Component {}

    assert.strictEqual(
      getBlockDisplayMetadata(SingleBlock).displayName,
      "Display Default Single"
    );
    assert.strictEqual(
      getBlockDisplayMetadata(MultiWordBlock).displayName,
      "Display Default Multi Word"
    );
  });

  test("falls back to 'cube' for icon and 'Misc' for category", function (assert) {
    @block("display-default-icon-and-category")
    class DefaultsBlock extends Component {}

    const display = getBlockDisplayMetadata(DefaultsBlock);
    assert.strictEqual(display.icon, "cube");
    assert.strictEqual(display.category, "Misc");
  });

  test("derives previewArgs from arg-schema defaults when unset", function (assert) {
    @block("display-default-preview", {
      args: {
        title: { type: "string", default: "Welcome" },
        level: { type: "number", default: 2 },
        align: { type: "string" }, // no default — should be omitted
      },
    })
    class DefaultPreviewBlock extends Component {}

    assert.deepEqual(getBlockDisplayMetadata(DefaultPreviewBlock).previewArgs, {
      title: "Welcome",
      level: 2,
    });
  });

  test("falls back to null for thumbnail", function (assert) {
    @block("display-default-thumbnail")
    class DefaultThumbnailBlock extends Component {}

    assert.strictEqual(
      getBlockDisplayMetadata(DefaultThumbnailBlock).thumbnail,
      null
    );
  });

  test("passes a loader-thunk thumbnail through untouched", function (assert) {
    // A lazily-loaded thumbnail: a function that resolves to a component. It is
    // accepted at decoration time and stored (and returned) as-is, so the
    // consumer can resolve it when it actually needs to render.
    const loader = () => Promise.resolve({ default: class {} });

    @block("display-lazy-thumbnail", { thumbnail: loader })
    class LazyThumbnailBlock extends Component {}

    assert.strictEqual(
      getBlockDisplayMetadata(LazyThumbnailBlock).thumbnail,
      loader,
      "the loader function is stored and returned untouched"
    );
  });
});
