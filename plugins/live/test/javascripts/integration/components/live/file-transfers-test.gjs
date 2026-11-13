import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { i18n } from "discourse-i18n";
import LiveFileTransfers from "discourse/plugins/live/discourse/components/live/file-transfers";

class LiveWebrtcStub extends Service {
  @tracked fileTransfers = [];
  calls = [];

  async getReceivedFile() {
    return this.receivedFile;
  }

  acceptFileTransfer(id) {
    this.calls.push(["accept", id]);
  }

  rejectFileTransfer(id) {
    this.calls.push(["reject", id]);
  }

  cancelFileTransfer(id) {
    this.calls.push(["cancel", id]);
  }

  dismissFileTransfer(id) {
    this.calls.push(["dismiss", id]);
    this.fileTransfers = this.fileTransfers.filter(
      (transfer) => transfer.id !== id
    );
  }
}

class LiveRoomsStub extends Service {
  roomById() {
    return {
      name: "Watercooler",
      active_participants: [{ id: 2, username: "bob" }],
    };
  }
}

module("Integration | Component | LiveFileTransfers", function (hooks) {
  setupRenderingTest(hooks);
  hooks.beforeEach(function () {
    this.owner.unregister("service:live-webrtc");
    this.owner.register("service:live-webrtc", LiveWebrtcStub);
    this.owner.unregister("service:live-rooms");
    this.owner.register("service:live-rooms", LiveRoomsStub);
    this.webrtc = this.owner.lookup("service:live-webrtc");
    this.transfer = {
      id: "transfer-1",
      roomId: 1,
      userId: 2,
      name: "hello.txt",
      size: 1024,
      direction: "incoming",
      status: "pending",
      progress: 0,
    };
    this.webrtc.fileTransfers = [this.transfer];
  });
  hooks.afterEach(function () {
    sinon.restore();
  });

  test("collapses accessibly, retains the pending summary, and expands for new offers", async function (assert) {
    await render(<template><LiveFileTransfers /></template>);
    assert
      .dom(".live-file-transfers__toggle")
      .hasAttribute("aria-expanded", "true");
    await click(".live-file-transfers__toggle");
    assert
      .dom(".live-file-transfers__toggle")
      .hasAttribute("aria-expanded", "false");
    assert.dom(".live-file-transfers__toggle").hasText("Expand");
    assert.dom("#live-file-transfers-list").isNotVisible();
    assert.dom(".live-file-transfers__summary").hasText("1 pending offer");

    this.webrtc.fileTransfers = [{ ...this.transfer }];
    await settled();
    assert
      .dom("#live-file-transfers-list")
      .isNotVisible("same offer updates do not reopen the panel");
    await click(".live-file-transfers__toggle");
    assert.dom("#live-file-transfers-list").isVisible();
    assert
      .dom(".live-file-transfers__toggle")
      .hasAttribute("aria-expanded", "true");
    await click(".live-file-transfers__toggle");

    this.webrtc.fileTransfers = [
      this.transfer,
      { ...this.transfer, id: "transfer-2" },
    ];
    await settled();
    assert
      .dom("#live-file-transfers-list")
      .isVisible("a new incoming offer expands the panel");
    assert
      .dom(".live-file-transfers__toggle")
      .hasAttribute("aria-expanded", "true");
    assert.dom(".live-file-transfers__summary").hasText("2 pending offers");
    await click(".live-file-transfers__toggle");
    assert
      .dom("#live-file-transfers-list")
      .isNotVisible("the newly expanded panel can be collapsed again");
  });

  test("offers persist without any participant dropdown, with explicit consent", async function (assert) {
    await render(<template><LiveFileTransfers /></template>);
    assert.dom(".live-file-transfer__peer").includesText("From bob");
    assert.dom(".live-file-transfer__peer").includesText("Watercooler");
    assert.dom(".live-file-transfer__name").includesText("hello.txt (1 KB)");
    assert.dom(".live-file-transfer__safety").includesText("not scanned");
    assert.dom(".live-file-transfer__save").doesNotExist();
    assert.dom("iframe, img, video, object, embed").doesNotExist();
    await click(".live-file-transfer__accept");
    await click(".live-file-transfer__reject");
    assert.deepEqual(this.webrtc.calls, [
      ["accept", "transfer-1"],
      ["reject", "transfer-1"],
    ]);
  });

  test("reactive progress, cancellation, terminal status and dismissal", async function (assert) {
    this.webrtc.fileTransfers = [
      { ...this.transfer, direction: "outgoing", status: "waiting" },
    ];
    await render(<template><LiveFileTransfers /></template>);
    assert.dom(".live-file-transfer__peer").includesText("To bob");
    assert.dom(".live-file-transfer__accept").doesNotExist();
    this.webrtc.fileTransfers = [
      { ...this.transfer, status: "transferring", progress: 0.42 },
    ];
    await settled();
    assert.dom("progress").hasAttribute("value", "42");
    await click(".live-file-transfer__cancel");
    assert.deepEqual(this.webrtc.calls, [["cancel", "transfer-1"]]);
    for (const status of ["completed", "cancelled", "rejected", "failed"]) {
      this.webrtc.fileTransfers = [{ ...this.transfer, status }];
      await settled();
      assert
        .dom(".live-file-transfer__status")
        .hasText(i18n(`live.file_transfer.status.${status}`));
      assert.dom(".live-file-transfer__cancel").doesNotExist();
    }
    await click(".live-file-transfer__dismiss");
    assert.dom(".live-file-transfers").doesNotExist();
  });

  test("preparing disk storage remains cancellable, not dismissible", async function (assert) {
    this.webrtc.fileTransfers = [{ ...this.transfer, status: "initializing" }];
    await render(<template><LiveFileTransfers /></template>);
    assert
      .dom(".live-file-transfer__status")
      .hasText(i18n("live.file_transfer.status.initializing"));
    assert.dom("progress").hasAttribute("value", "0");
    assert.dom(".live-file-transfer__dismiss").doesNotExist();
    assert.dom(".live-file-transfer__accept").doesNotExist();
    await click(".live-file-transfer__cancel");
    assert.deepEqual(this.webrtc.calls, [["cancel", "transfer-1"]]);
  });

  test("storage failures show only known localized explanations", async function (assert) {
    await render(<template><LiveFileTransfers /></template>);
    for (const code of [
      "storage_unavailable",
      "storage_failed",
      "storage_insufficient",
    ]) {
      this.webrtc.fileTransfers = [
        { ...this.transfer, status: "failed", error: code },
      ];
      await settled();
      assert
        .dom(".live-file-transfer__error")
        .hasText(i18n(`live.file_transfer.${code}`));
    }
    this.webrtc.fileTransfers = [
      { ...this.transfer, status: "failed", error: "untrusted remote error" },
    ];
    await settled();
    assert.dom(".live-file-transfer__error").doesNotExist();
    assert
      .dom(".live-file-transfers")
      .doesNotIncludeText("untrusted remote error");
  });

  test("completed content is only downloaded on Save, with safe attachment metadata", async function (assert) {
    const blob = new Blob(["<html>untrusted</html>"], { type: "text/html" });
    this.webrtc.receivedFile = blob;
    this.webrtc.fileTransfers = [
      {
        ...this.transfer,
        status: "completed",
        name: "../evil\u202e.html",
        hasFile: true,
      },
    ];
    const create = sinon
      .stub(URL, "createObjectURL")
      .returns("blob:test-file-transfer");
    const revoke = sinon.stub(URL, "revokeObjectURL");
    const anchorClick = sinon.stub(HTMLAnchorElement.prototype, "click");
    const originalTimeout = window.setTimeout;
    let cleanup;
    sinon.stub(window, "setTimeout").callsFake((callback, delay, ...args) => {
      if (delay === 20_000) {
        cleanup = callback;
        return 0;
      }
      return originalTimeout(callback, delay, ...args);
    });
    await render(<template><LiveFileTransfers /></template>);
    assert.false(
      create.called,
      "does not automatically download or preview received content"
    );
    await click(".live-file-transfer__save");
    assert.true(create.calledOnce);
    assert.strictEqual(
      create.firstCall.args[0].type,
      "application/octet-stream"
    );
    assert.true(anchorClick.calledOnce);
    const link = anchorClick.firstCall.thisValue;
    assert.strictEqual(link.download, "_evil_.html");
    assert.strictEqual(link.rel, "noopener");
    assert.strictEqual(
      this.webrtc.receivedFile,
      blob,
      "keeps content until explicit dismissal"
    );
    assert.false(
      revoke.called,
      "URL remains alive long enough for the browser download"
    );
    cleanup();
    assert.true(revoke.calledOnceWithExactly("blob:test-file-transfer"));
  });
});
