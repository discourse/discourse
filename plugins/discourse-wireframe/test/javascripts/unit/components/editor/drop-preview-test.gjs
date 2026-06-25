import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DropPreview from "discourse/plugins/discourse-wireframe/discourse/components/editor/drop-preview";

const DESCRIPTOR = {
  kind: "slot-insert",
  geometry: { top: 10, left: 10, width: 100, height: 40 },
  previewKind: "insert",
  validity: "valid",
  label: "Drop here",
};

/** Minimal stub exposing only the slot preview `DropPreview` reads. */
class StubDragOverlayService extends Service {
  slotPreview = null;
}

function stubDragOverlay(owner, descriptor) {
  owner.unregister("service:wireframe-drag-overlay");
  const stub = new StubDragOverlayService(owner);
  stub.slotPreview = descriptor;
  owner.register("service:wireframe-drag-overlay", stub, {
    instantiate: false,
  });
}

module("Integration | Wireframe | DropPreview", function (hooks) {
  setupRenderingTest(hooks);

  test("renders one overlay at the descriptor's geometry, with kind/validity", async function (assert) {
    stubDragOverlay(this.owner, DESCRIPTOR);

    await render(<template><DropPreview /></template>);

    assert
      .dom(".wireframe-drop-preview")
      .exists({ count: 1 }, "one overlay is rendered for the descriptor")
      .hasClass("wireframe-drop-preview--insert", "carries the kind modifier")
      .hasClass(
        "wireframe-drop-preview--valid",
        "carries the validity modifier"
      );
    assert
      .dom(".wireframe-drop-preview__label")
      .hasText("Drop here", "renders the operation label");
  });

  test("renders nothing when there is no descriptor", async function (assert) {
    stubDragOverlay(this.owner, null);

    await render(<template><DropPreview /></template>);

    assert
      .dom(".wireframe-drop-preview")
      .doesNotExist("no overlay without an active descriptor");
  });
});
