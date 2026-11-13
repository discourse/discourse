import Service from "@ember/service";
import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import ModalContainer from "discourse/components/modal-container";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import LiveSendFileModal from "discourse/plugins/live/discourse/components/modal/live-send-file";

class LiveWebrtcStub extends Service {
  available = true;
  calls = [];
  maxFileTransferSize = 100 * 1024 * 1024;

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

  test("displays the configured limit and rejects one byte over it", async function (assert) {
    this.webrtc.maxFileTransferSize = 1024 * 1024;
    this.owner.lookup("service:modal").close();
    this.owner
      .lookup("service:modal")
      .show(LiveSendFileModal, { model: this.model });
    await settled();
    assert
      .dom(".live-send-file-modal")
      .includesText("Maximum file size: 1 MiB.", "help uses the service limit");
    await triggerEvent("input[type=file]", "change", {
      files: [{ name: "large.bin", size: 1024 * 1024 + 1 }],
    });
    assert
      .dom("[role=alert]")
      .includesText("1 MiB", "error uses the same limit");
    assert.strictEqual(
      this.webrtc.calls.length,
      0,
      "oversized selection never reaches transport"
    );
  });

  test("allows a selection exactly at a custom limit", async function (assert) {
    this.webrtc.maxFileTransferSize = 1024 * 1024;
    const file = new File([], "exact.bin");
    Object.defineProperty(file, "size", {
      value: this.webrtc.maxFileTransferSize,
    });
    await triggerEvent("input[type=file]", "change", { files: [file] });
    assert.deepEqual(
      this.webrtc.calls,
      [[1, 2, file]],
      "exact limit reaches transport"
    );
    assert
      .dom(".live-send-file-modal")
      .doesNotExist("successful selection closes the picker");
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
