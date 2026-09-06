import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import downloadBlob, { triggerBlobDownload } from "discourse/lib/download-blob";

function captureAnchor() {
  const original = document.createElement.bind(document);
  const created = [];
  const stub = sinon
    .stub(document, "createElement")
    .callsFake(function (tagName) {
      const el = original(tagName);
      if (tagName === "a") {
        created.push(el);
        sinon.stub(el, "click");
      }
      return el;
    });
  return { created, stub };
}

module("Unit | Utility | download-blob", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    sinon.stub(URL, "createObjectURL").returns("blob:mock");
    sinon.stub(URL, "revokeObjectURL");
  });

  test("triggerBlobDownload uses fallbackFilename when no Content-Disposition", function (assert) {
    const { created } = captureAnchor();

    triggerBlobDownload(new Blob(["x"]), { fallbackFilename: "fallback.zip" });

    assert.strictEqual(created.length, 1);
    assert.strictEqual(created[0].getAttribute("download"), "fallback.zip");
    assert.strictEqual(created[0].getAttribute("href"), "blob:mock");
    assert.true(created[0].click.calledOnce);
  });

  test("triggerBlobDownload prefers the filename from Content-Disposition", function (assert) {
    const { created } = captureAnchor();

    triggerBlobDownload(new Blob(["x"]), {
      fallbackFilename: "fallback.zip",
      contentDisposition: 'attachment; filename="server-name.zip"',
    });

    assert.strictEqual(created[0].getAttribute("download"), "server-name.zip");
  });

  test("triggerBlobDownload parses RFC 5987 UTF-8 filename*", function (assert) {
    const { created } = captureAnchor();

    triggerBlobDownload(new Blob(["x"]), {
      contentDisposition:
        "attachment; filename=\"ascii-fallback.zip\"; filename*=UTF-8''caf%C3%A9.zip",
    });

    assert.strictEqual(created[0].getAttribute("download"), "café.zip");
  });

  test("triggerBlobDownload falls back to ASCII match when UTF-8 form is malformed", function (assert) {
    const { created } = captureAnchor();

    triggerBlobDownload(new Blob(["x"]), {
      contentDisposition:
        "attachment; filename=\"ascii-only.zip\"; filename*=UTF-8''%E0%A4%A",
    });

    assert.strictEqual(created[0].getAttribute("download"), "ascii-only.zip");
  });

  test("triggerBlobDownload omits the download attribute when no filename is available", function (assert) {
    const { created } = captureAnchor();

    triggerBlobDownload(new Blob(["x"]));

    assert.false(created[0].hasAttribute("download"));
  });

  test("downloadBlob fetches the URL and triggers a download", async function (assert) {
    const { created } = captureAnchor();
    const blob = new Blob(["zip-bytes"]);
    const fetchStub = sinon.stub(window, "fetch").resolves(
      new Response(blob, {
        status: 200,
        headers: { "Content-Disposition": 'attachment; filename="theme.zip"' },
      })
    );

    await downloadBlob("/some/export");

    assert.true(
      fetchStub.calledWith(
        "/some/export",
        sinon.match({ credentials: "same-origin" })
      )
    );
    assert.strictEqual(created[0].getAttribute("download"), "theme.zip");
  });

  test("downloadBlob throws on non-2xx responses without triggering a download", async function (assert) {
    const { created } = captureAnchor();
    sinon.stub(window, "fetch").resolves(new Response("nope", { status: 500 }));

    await assert.rejects(downloadBlob("/some/export"), /Download failed: 500/);
    assert.strictEqual(created.length, 0);
  });
});
