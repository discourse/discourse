import { module, test } from "qunit";
import Section from "discourse/blocks/builtin/section";
import { getBlockMetadata } from "discourse/lib/blocks/-internals/decorator";

module("Unit | Blocks | section overlay visibility", function () {
  const visible = (args) =>
    getBlockMetadata(Section).args.scrim.ui.visibleWhen({
      args,
      siteSettings: {},
      site: {},
    });

  test("hidden without a background image", function (assert) {
    assert.false(visible({}));
    assert.false(visible({ backgroundImage: undefined }));
    assert.false(visible({ backgroundImage: { url: "" } }));
  });

  test("shown once a background image is set", function (assert) {
    assert.true(visible({ backgroundImage: { url: "/uploads/hero.png" } }));
  });
});
