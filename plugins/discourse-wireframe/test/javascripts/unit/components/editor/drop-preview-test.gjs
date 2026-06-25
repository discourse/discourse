import Service from "@ember/service";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DropPreview from "discourse/plugins/discourse-wireframe/discourse/components/editor/drop-preview";

const DESCRIPTOR = {
  geometry: { top: 10, left: 10, width: 100, height: 40 },
  kind: "insert",
  validity: "valid",
  label: "Drop here",
};

/** Minimal stub exposing only the descriptor `DropPreview` reads. */
class StubWireframeService extends Service {
  activeDropPreview = null;
}

function stubWireframe(owner, descriptor) {
  owner.unregister("service:wireframe");
  const stub = new StubWireframeService(owner);
  stub.activeDropPreview = descriptor;
  owner.register("service:wireframe", stub, { instantiate: false });
}

module("Integration | Wireframe | DropPreview", function (hooks) {
  setupRenderingTest(hooks);

  test("renders one overlay at the descriptor's geometry, with kind/validity", async function (assert) {
    stubWireframe(this.owner, DESCRIPTOR);

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
    stubWireframe(this.owner, null);

    await render(<template><DropPreview /></template>);

    assert
      .dom(".wireframe-drop-preview")
      .doesNotExist("no overlay without an active descriptor");
  });
});
