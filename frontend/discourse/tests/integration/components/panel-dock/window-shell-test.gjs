import { module, test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  shellWindow,
  writeForeignPage,
} from "discourse/tests/helpers/panel-dock-window-shell";
import {
  adoptShell,
  shellKey,
  shellReady,
} from "discourse/ui-kit/panel-dock/-internals/window-shell";

const NOTE = ".d-panel-dock-window__reconnecting";
const STATUS = `${NOTE} [role="status"]`;

/**
 * Oracle for taking over a document the server rendered.
 *
 * The window is no longer written by the page that opens it: it arrives with a
 * shell already in it, possibly still parsing, possibly not ours at all. So the
 * question this module answers is not "did we build it right" but "can we tell
 * what we have been handed, and can we probe it without damaging it".
 */
module("Integration | Component | panel dock window shell", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.frames = [];
    this.cleanups = [];
  });

  hooks.afterEach(function () {
    this.cleanups.forEach((fn) => fn());
    this.frames.forEach((frame) => frame.remove());
    sinon.restore();
  });

  /** A same-origin document that is reachable but is not a panel window. */
  function foreignPage(context) {
    const frame = document.createElement("iframe");
    frame.setAttribute("aria-hidden", "true");
    document.body.appendChild(frame);
    context.frames.push(frame);
    writeForeignPage(frame.contentDocument);
    return frame.contentDocument;
  }

  test("window shell reads the key the server stamped", function (assert) {
    const { doc } = shellWindow(this, "oracle-key");

    assert.strictEqual(shellKey(doc), "oracle-key");
  });

  test("window shell reports no key for a document that is not a panel window", function (assert) {
    assert.strictEqual(shellKey(foreignPage(this)), undefined);
  });

  test("window shell is ready only when the key matches and the mount is there", function (assert) {
    const { doc } = shellWindow(this, "oracle-key");

    assert.true(shellReady(doc, "oracle-key"), "the served shell is ready");
    assert.false(
      shellReady(doc, "another-panel"),
      "a window serving a different panel is not ours to take"
    );
    assert.false(
      shellReady(foreignPage(this), "oracle-key"),
      "a page that is not a shell is never ready"
    );
  });

  test("window shell is not ready while its mount is still missing", function (assert) {
    const { doc } = shellWindow(this, "oracle-key");
    doc.querySelector(".d-panel-dock-window__mount").remove();

    // A document mid-parse has the marker on `<html>` long before it has the
    // body the marker promises, so the marker alone cannot be the gate.
    assert.false(shellReady(doc, "oracle-key"));
  });

  test("window shell refuses a document that is not ours and leaves it as it found it", function (assert) {
    const doc = foreignPage(this);
    const before = doc.body.innerHTML;

    assert.strictEqual(adoptShell(doc, "oracle-key"), null);
    assert.strictEqual(
      doc.body.innerHTML,
      before,
      "validated before anything was written, so a repeated probe is safe"
    );
  });

  test("window shell clears the mount and both float outlets it adopts", function (assert) {
    const { doc } = shellWindow(this, "oracle-key");

    // Everything a previous page left behind, in all three places it could
    // have left it. The outlets sit outside the mount, so emptying the mount
    // alone leaves a stale menu visible in the window.
    doc.querySelector(".d-panel-dock-window__mount").innerHTML =
      "<p>stale panel</p>";
    doc.querySelector("#d-menu-portals").innerHTML = "<div>stale menu</div>";
    doc.querySelector("#d-tooltip-portals").innerHTML =
      "<div>stale tooltip</div>";

    const shell = adoptShell(doc, "oracle-key");
    this.cleanups.push(() => shell.dispose());

    assert.dom(".d-panel-dock-window__mount", doc).hasNoText();
    assert.dom("#d-menu-portals", doc).hasNoText();
    assert.dom("#d-tooltip-portals", doc).hasNoText();
  });

  test("window shell hands back the mount the panel renders into", function (assert) {
    const { doc, mount } = shellWindow(this, "oracle-key");
    const shell = adoptShell(doc, "oracle-key");
    this.cleanups.push(() => shell.dispose());

    assert.strictEqual(shell.mount, mount);
  });

  test("window shell routes a link clicked in the window through the opening page", function (assert) {
    const routeTo = sinon.stub(DiscourseURL, "routeTo");
    const { doc } = shellWindow(this, "oracle-key");
    const shell = adoptShell(doc, "oracle-key");
    this.cleanups.push(() => shell.dispose());

    let prevented = null;
    const guard = (event) => {
      prevented = event.defaultPrevented;
      event.preventDefault();
    };
    doc.addEventListener("click", guard);
    this.cleanups.push(() => doc.removeEventListener("click", guard));

    const link = doc.createElement("a");
    link.href = "/t/oracle-topic/1";
    shell.mount.appendChild(link);

    link.dispatchEvent(
      new doc.defaultView.MouseEvent("click", {
        bubbles: true,
        cancelable: true,
        button: 0,
      })
    );

    // Without this the click navigates the window itself, which destroys the
    // tree the opening page is rendering into it.
    assert.true(prevented, "the window has no router of its own");
    assert.true(routeTo.calledWith("/t/oracle-topic/1"));
  });

  test("window shell shows the note in place of the panel and keeps the mount", function (assert) {
    const { doc, mount } = shellWindow(this, "oracle-key");
    const shell = adoptShell(doc, "oracle-key");
    this.cleanups.push(() => shell.dispose());

    shell.setNote("Reload that page to reconnect it, or close this window.");

    assert.dom(".d-panel-dock-window", doc).hasClass("is-reconnecting");
    assert.dom(NOTE, doc).doesNotHaveAttribute("hidden");

    // Written at the moment of the event, not served populated: a live region
    // that already holds its text and is merely unhidden does not announce.
    assert
      .dom(STATUS, doc)
      .hasText("Reload that page to reconnect it, or close this window.");

    assert.strictEqual(
      doc.querySelector(".d-panel-dock-window__mount"),
      mount,
      "the mount is hidden rather than discarded, so the tree in it survives"
    );
  });

  test("window shell clears the note and empties its live region", function (assert) {
    const { doc } = shellWindow(this, "oracle-key");
    const shell = adoptShell(doc, "oracle-key");
    this.cleanups.push(() => shell.dispose());

    shell.setNote("Reload that page to reconnect it, or close this window.");
    shell.setNote(null);

    assert.dom(".d-panel-dock-window", doc).doesNotHaveClass("is-reconnecting");
    assert.dom(NOTE, doc).hasAttribute("hidden");

    // Emptied on the way out, so showing it again is a real content change and
    // announces a second time.
    assert.dom(STATUS, doc).hasNoText();
  });

  test("window shell stops routing clicks once disposed", function (assert) {
    const routeTo = sinon.stub(DiscourseURL, "routeTo");
    const { doc } = shellWindow(this, "oracle-key");
    const shell = adoptShell(doc, "oracle-key");

    shell.dispose();

    const link = doc.createElement("a");
    link.href = "/t/oracle-topic/1";
    shell.mount.appendChild(link);
    link.dispatchEvent(
      new doc.defaultView.MouseEvent("click", {
        bubbles: true,
        cancelable: true,
        button: 0,
      })
    );

    assert.false(routeTo.called, "a disposed shell owns nothing in the window");
  });
});
