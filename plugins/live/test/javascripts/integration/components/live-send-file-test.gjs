import Service from "@ember/service";
import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LiveSendFileModal from "discourse/plugins/live/discourse/components/modal/live-send-file";

class LiveWebrtcStub extends Service {
  available = true;
  calls = [];

  canSendFile() {
    return this.available;
  }

  sendFile(...args) {
    this.calls.push(args);
  }
}

module("Integration | Component | LiveSendFileModal", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(async function () {
    this.owner.unregister("service:live-webrtc");
    this.owner.register("service:live-webrtc", LiveWebrtcStub);
    this.webrtc = this.owner.lookup("service:live-webrtc");
    this.model = { room: { id: 1 }, participant: { id: 2, username: "bob" } };
    await render(<template><ModalContainer /></template>);
    this.owner
      .lookup("service:modal")
      .show(LiveSendFileModal, { model: this.model });
    await settled();
  });

  test("sends the selected file and closes the picker", async function (assert) {
    const file = new File(["hello"], "hello.txt");
    await triggerEvent("input[type=file]", "change", {
      files: [file],
    });
    assert.deepEqual(this.webrtc.calls, [[1, 2, file]]);
    assert
      .dom(".live-send-file-modal")
      .doesNotExist("sending closes the picker");
  });

  test("rejects oversized selections before calling transport", async function (assert) {
    await triggerEvent("input[type=file]", "change", {
      files: [{ name: "huge.bin", size: 100 * 1024 * 1024 + 1 }],
    });
    assert.dom("[role=alert]").includesText("100 MiB");
    assert.strictEqual(this.webrtc.calls.length, 0);
    assert
      .dom(".live-send-file-modal")
      .exists("invalid selection keeps the picker open");
  });

  test("rechecks peer eligibility after the picker opens", async function (assert) {
    this.webrtc.available = false;
    await triggerEvent("input[type=file]", "change", {
      files: [new File(["hi"], "hi.txt")],
    });
    assert.dom("[role=alert]").exists();
    assert.strictEqual(this.webrtc.calls.length, 0);
  });
});
