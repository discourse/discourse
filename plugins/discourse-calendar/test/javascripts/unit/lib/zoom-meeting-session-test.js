import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import ZoomMeetingSession from "../../discourse/lib/zoom-meeting-session";

// `document.hidden` is an inherited accessor, so it can only be faked by
// shadowing it on the document itself.
function stubDocumentHidden(hidden) {
  Object.defineProperty(document, "hidden", {
    configurable: true,
    get: () => hidden,
  });
}

function restoreDocumentHidden() {
  delete document.hidden;
}

// The view sync runs in a frame callback, which `settled` knows nothing about.
function nextFrame() {
  return new Promise((resolve) => requestAnimationFrame(resolve));
}

module("Unit | Lib | ZoomMeetingSession", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    restoreDocumentHidden();
  });

  test("defers sizing Zoom's view while the document is hidden", async function (assert) {
    const session = new ZoomMeetingSession(getOwner(this), {
      topicId: 1,
      canJoin: () => true,
    });
    sinon.stub(session, "performJoin").resolves();
    const syncVideoSize = sinon.stub(session, "syncVideoSize");
    session.zoomClient = { updateVideoOptions: () => {} };

    stubDocumentHidden(true);

    await session.join();
    await nextFrame();

    assert.false(
      syncVideoSize.called,
      "frame callbacks do not run in a background tab"
    );

    stubDocumentHidden(false);
    document.dispatchEvent(new Event("visibilitychange"));
    await nextFrame();

    assert.true(
      syncVideoSize.called,
      "the view is sized once the tab is visible again"
    );

    session.teardown();
  });

  test("sizes Zoom's view straight away when the document is visible", async function (assert) {
    const session = new ZoomMeetingSession(getOwner(this), {
      topicId: 1,
      canJoin: () => true,
    });
    sinon.stub(session, "performJoin").resolves();
    const syncVideoSize = sinon.stub(session, "syncVideoSize");

    stubDocumentHidden(false);

    await session.join();
    await nextFrame();

    assert.true(syncVideoSize.called);

    session.teardown();
  });

  test("stops listening for visibility changes once torn down", async function (assert) {
    const session = new ZoomMeetingSession(getOwner(this), {
      topicId: 1,
      canJoin: () => true,
    });
    const syncVideoSize = sinon.stub(session, "syncVideoSize");
    session.zoomClient = { updateVideoOptions: () => {} };

    stubDocumentHidden(false);
    session.teardown();

    document.dispatchEvent(new Event("visibilitychange"));
    await nextFrame();

    assert.false(syncVideoSize.called);
  });
});
