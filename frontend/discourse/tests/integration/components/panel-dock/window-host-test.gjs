import { getResolver, settled } from "@ember/test-helpers";
import buildOwner from "@ember/test-helpers/build-owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { IframeWindowHost } from "discourse/tests/helpers/panel-dock-window-host";
import {
  default as BrowserWindowHost,
  WINDOW_HOST_REGISTRATION,
  windowHostFor,
} from "discourse/ui-kit/panel-dock/-internals/window-host";
import { shellKey } from "discourse/ui-kit/panel-dock/-internals/window-shell";

const STRINGS = Object.freeze({
  title: "Window host oracle",
  note: {
    title: "The opening page went away",
    body: "Reload it to reconnect this panel.",
  },
});

// Permanent in the served shell and toggled by `hidden`, rather than inserted
// and removed the way the opener-written skeleton did it — so "showing" has to
// be part of the selector or every assertion about it is true at once.
const NOTE_SELECTOR = ".d-panel-dock-window__reconnecting:not([hidden])";

function acquired(outcome, assert) {
  assert.strictEqual(outcome.status, "acquired", "the lease is acquired");
  return outcome.handle;
}

function connecting(outcome, assert) {
  assert.strictEqual(outcome.status, "connecting", "the window is on its way");
  return outcome.connection;
}

/** Records what a connection reported, so a test can assert on the transition. */
function watch(connection) {
  const events = { ready: [], failed: [] };
  connection.onReady((handle) => events.ready.push(handle));
  connection.onFailed((reason) => events.failed.push(reason));
  return events;
}

/** Drives an open all the way through the load its connection waits for. */
function opened(host, key, assert, geometry) {
  const events = watch(connecting(host.open(key, STRINGS, geometry), assert));
  host.finishLoad(key);
  host.tick(key);
  assert.strictEqual(
    events.ready.length,
    1,
    "the loaded window is delivered to the connection"
  );

  return events.ready[0];
}

async function flushResize(host, name) {
  await new Promise((resolve) => requestAnimationFrame(resolve));
  host.flushPopupAnimationFrame(name);
  await settled();
}

module("Integration | Component | panel dock window host", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.hosts = [];
  });

  hooks.afterEach(function () {
    this.hosts.reverse().forEach((host) => host.teardown());
    sinon.restore();
  });

  function hostFor(context) {
    const host = new IframeWindowHost();
    context.hosts.push(host);
    return host;
  }

  test("window host opens a fresh marked shell and applies the requested geometry", function (assert) {
    const host = hostFor(this);
    const key = "fresh-shell";
    const baseline = host.seedBlankWindow("geometry-probe");
    const measured = {
      width: baseline.outerWidth + 83,
      height: baseline.outerHeight + 61,
      left: baseline.screenX + 47,
      top: baseline.screenY + 29,
    };

    const handle = opened(host, key, assert, measured);

    assert.deepEqual(
      handle.measure(),
      measured,
      "the geometry comes from the caller without accidental clamping"
    );
    assert.strictEqual(
      shellKey(handle.mount.ownerDocument),
      key,
      "the fresh document is marked with its lease key"
    );
    assert.strictEqual(
      handle.mount.ownerDocument.title,
      STRINGS.title,
      "the fresh shell has the resolved title"
    );
    assert.strictEqual(host.openCount, 1, "the double observed one open call");
  });

  test("window host refuses a blocked open without creating a lease", function (assert) {
    const host = hostFor(this);
    host.armNextResolveRefusal();

    assert.deepEqual(
      host.open("blocked-window", STRINGS),
      { status: "unavailable" },
      "a refused browser window is unavailable"
    );

    const retry = opened(host, "blocked-window", assert);
    assert.false(retry.closed, "the refusal did not leave a phantom lease");
    assert.strictEqual(
      host.resolveCount,
      2,
      "the retry reaches the browser again"
    );
  });

  test("window host passes finite stored coordinates through to the browser", function (assert) {
    const windowOpen = sinon.stub(window, "open").returns(null);
    const host = new BrowserWindowHost();

    host.open("negative-position", STRINGS, {
      width: 640,
      height: 480,
      left: -780,
      top: 90,
    });
    assert.strictEqual(
      windowOpen.firstCall.args[2],
      "popup,width=640,height=480,left=-780,top=90",
      "a position entirely left of the current display is preserved"
    );

    host.open("far-position", STRINGS, {
      width: 640,
      height: 480,
      left: screen.availWidth + 250,
      top: 120,
    });
    assert.strictEqual(
      windowOpen.secondCall.args[2],
      `popup,width=640,height=480,left=${screen.availWidth + 250},top=120`,
      "a position beyond the current display is preserved"
    );

    host.open("invalid-position", STRINGS, {
      width: Infinity,
      height: NaN,
      left: undefined,
      top: null,
    });
    assert.strictEqual(
      windowOpen.thirdCall.args[2],
      "popup",
      "non-finite or missing geometry adds no window features"
    );
  });

  test("window host drops stored dimensions when either dimension is non-finite", function (assert) {
    const windowOpen = sinon.stub(window, "open").returns(null);
    const host = new BrowserWindowHost();

    host.open("infinite-width", STRINGS, {
      width: Infinity,
      height: 480,
      left: 0,
      top: 0,
    });
    host.open("infinite-height", STRINGS, {
      width: 640,
      height: Infinity,
      left: 0,
      top: 0,
    });
    assert.deepEqual(
      windowOpen.getCalls().map((call) => call.args[2]),
      ["popup,left=0,top=0", "popup,left=0,top=0"],
      "either non-finite dimension drops both dimensions but preserves valid coordinates"
    );
  });

  test("window host protects one application-wide lease from another host", function (assert) {
    const firstHost = hostFor(this);
    const secondHost = hostFor(this);
    const key = "shared-lease";
    const first = opened(firstHost, key, assert);

    assert.deepEqual(
      secondHost.adopt(key, STRINGS),
      { status: "already-leased" },
      "a different host cannot take the same application-wide key"
    );
    assert.strictEqual(
      secondHost.resolveCount,
      0,
      "the competing request changes no browser state"
    );
    assert.false(first.closed, "the original lease remains untouched");
  });

  test("window host open reaps a lease whose reader window is already closed", function (assert) {
    const firstHost = hostFor(this);
    const secondHost = hostFor(this);
    const key = "closed-before-open";
    const stale = opened(firstHost, key, assert);
    firstHost.closeAsReader(key);

    const replacementClosed = opened(secondHost, key, assert).closed;

    assert.true(stale.closed, "the stale handle observes its closed window");
    assert.false(replacementClosed, "open acquires a fresh live window");
    assert.strictEqual(
      firstHost.listenerCount("pagehide"),
      0,
      "reaping the stale handle releases its host"
    );
  });

  test("window host adopt reaps a lease whose reader window is already closed", function (assert) {
    const firstHost = hostFor(this);
    const secondHost = hostFor(this);
    const key = "closed-before-adopt";
    opened(firstHost, key, assert);
    firstHost.closeAsReader(key);
    const prepared = secondHost.seedPreparedWindow(key, key);

    const outcome = secondHost.adopt(key, STRINGS);
    const adoptedPreparedWindow =
      outcome.status === "acquired" &&
      outcome.handle.mount.ownerDocument.defaultView === prepared.window;

    assert.strictEqual(outcome.status, "acquired", "adopt reclaims the lease");
    assert.true(
      adoptedPreparedWindow,
      "adopt takes over the prepared live window"
    );
    assert.strictEqual(
      firstHost.listenerCount("pagehide"),
      0,
      "reaping the stale handle releases its host"
    );
  });

  test("window host does not consume a refusal armed behind an existing lease", function (assert) {
    const owner = hostFor(this);
    const contender = hostFor(this);
    const key = "leased-before-refusal";
    const first = opened(owner, key, assert);
    contender.armNextResolveRefusal();

    assert.deepEqual(
      contender.open(key, STRINGS),
      { status: "already-leased" },
      "a lease conflict is distinct from browser refusal"
    );
    first.dispose();
    assert.deepEqual(
      contender.open(key, STRINGS),
      { status: "unavailable" },
      "the untouched refusal applies once resolving is legitimate"
    );
  });

  test("window host adopts only a window carrying the matching marker", function (assert) {
    const host = hostFor(this);
    const key = "marked-adoption";
    const previous = host.seedPreparedWindow(key, key);
    previous.mount.appendChild(previous.window.document.createElement("aside"));

    const handle = acquired(host.adopt(key, STRINGS), assert);

    assert.strictEqual(
      handle.mount.ownerDocument.defaultView,
      previous.window,
      "adoption reuses the named browser window"
    );
    // The mount is the one the server rendered, so adoption takes it over
    // rather than replacing it — what must not survive is the previous page's
    // tree inside it.
    assert.strictEqual(
      handle.mount,
      previous.mount,
      "adoption takes over the served mount"
    );
    assert.strictEqual(
      handle.mount.childElementCount,
      0,
      "the orphaned tree is removed"
    );
    assert.strictEqual(
      handle.mount.childElementCount,
      0,
      "the new mount starts empty"
    );
    assert.strictEqual(host.adoptCount, 1, "the double observed one adoption");
  });

  test("window host closes an unmarked named window rejected by adopt", function (assert) {
    const host = hostFor(this);
    const key = "unmarked-adoption";
    const blank = host.seedBlankWindow(key);

    assert.deepEqual(
      host.adopt(key, STRINGS),
      { status: "unavailable" },
      "a blank named window is not mistaken for a prior visit"
    );
    assert.true(
      blank.closed,
      "the rejected blank window is closed immediately"
    );
    assert.strictEqual(host.closeCount(key), 1, "it is closed exactly once");

    const retry = opened(host, key, assert);
    assert.notStrictEqual(
      retry.mount.ownerDocument.defaultView,
      blank,
      "the closed blank does not remain the named window"
    );
  });

  test("window host rewrites an existing named window when opening", function (assert) {
    const host = hostFor(this);
    const key = "rewrite-on-open";
    const previous = host.seedPreparedWindow(key, "some-other-key");
    previous.mount.appendChild(previous.window.document.createElement("aside"));

    const handle = opened(host, key, assert);

    assert.strictEqual(
      handle.mount.ownerDocument.defaultView,
      previous.window,
      "open follows named-window reuse"
    );
    assert.notStrictEqual(
      handle.mount,
      previous.mount,
      "open replaces the old shell"
    );
    assert.false(
      previous.mount.isConnected,
      "the old rendered tree is orphaned"
    );
    assert.strictEqual(
      shellKey(handle.mount.ownerDocument),
      key,
      "the new key wins"
    );
  });

  test("window host generations increase and an old double-dispose cannot release a new lease", function (assert) {
    const firstHost = hostFor(this);
    const secondHost = hostFor(this);
    const thirdHost = hostFor(this);
    const key = "generation-guard";
    const first = opened(firstHost, key, assert);
    first.dispose();
    const second = opened(secondHost, key, assert);

    first.dispose();
    assert.deepEqual(
      thirdHost.open(key, STRINGS),
      { status: "already-leased" },
      "stale cleanup cannot release the current generation"
    );
    assert.true(
      second.generation > first.generation,
      "the replacement lease receives a later generation"
    );

    second.dispose();
    const third = opened(thirdHost, key, assert);
    assert.true(
      third.generation > second.generation,
      "a later successful lease never reuses a generation"
    );
  });

  test("window host focuses and measures the live window while preserving a good measurement", function (assert) {
    const host = hostFor(this);
    const key = "focus-and-measure";
    const handle = opened(host, key, assert);
    const liveMeasurement = host.measurementFor(key);

    handle.focus();
    handle.focus();
    assert.strictEqual(
      host.focusCount,
      2,
      "each request reaches the browser window"
    );
    assert.deepEqual(
      handle.measure(),
      liveMeasurement,
      "measurement reflects all four values reported by the window"
    );

    host.reportZeroMeasurement(key);
    assert.strictEqual(
      handle.measure(),
      null,
      "a closing window cannot overwrite the last useful geometry with zeros"
    );

    host.setMeasurement(key, { ...liveMeasurement, width: 0 });
    assert.strictEqual(
      handle.measure(),
      null,
      "a non-positive width is invalid alone"
    );
    host.setMeasurement(key, { ...liveMeasurement, height: 0 });
    assert.strictEqual(
      handle.measure(),
      null,
      "a non-positive height is invalid alone"
    );
  });

  test("window host drives the shell note without replacing its mount", function (assert) {
    const host = hostFor(this);
    const key = "manual-note";
    const handle = opened(host, key, assert);
    // A handle only meets an unloading page once the panel has rendered
    // into its window; an uncommitted one is closed rather than handed on.
    handle.commit();
    const mount = handle.mount;
    const doc = mount.ownerDocument;

    handle.showNote();
    assert.dom(NOTE_SELECTOR, doc).exists("the lease note is shown");
    assert
      .dom(`${NOTE_SELECTOR} [role="status"]`, doc)
      .hasText(STRINGS.note.body, "the page writes the sentence it announces");
    assert
      .dom(`${NOTE_SELECTOR} .empty-state__title`, doc)
      .hasAnyText("the heading came with the served shell");
    assert.strictEqual(
      handle.mount,
      mount,
      "showing the note keeps the mount object"
    );

    handle.clearNote();
    assert.dom(NOTE_SELECTOR, doc).doesNotExist("the lease note is cleared");
    assert.strictEqual(
      handle.mount,
      mount,
      "clearing it keeps the mount object too"
    );
  });

  test("window host reports reader pagehide only while its lease is live", function (assert) {
    const host = hostFor(this);
    const key = "reader-pagehide";
    const handle = opened(host, key, assert);
    let calls = 0;
    handle.onPagehide(() => calls++);

    host.navigateReader(key);
    assert.strictEqual(calls, 1, "reader navigation reaches the live callback");

    handle.dispose();
    host.navigateReader(key);
    assert.strictEqual(calls, 1, "a callback arriving after disposal is stale");
  });

  test("window host reports reader resize only while its lease is live", async function (assert) {
    const host = hostFor(this);
    const key = "reader-resize";
    const handle = opened(host, key, assert);
    let calls = 0;
    handle.onResize(() => calls++);
    const initial = host.measurementFor(key);
    const resized = {
      width: initial.width + 37,
      height: initial.height + 23,
      left: initial.left + 19,
      top: initial.top + 11,
    };

    host.resizeReader(key, resized);
    await flushResize(host, key);
    assert.strictEqual(
      calls,
      1,
      "a resize is coalesced into one live callback"
    );
    assert.deepEqual(
      handle.measure(),
      resized,
      "the callback can observe the new geometry"
    );

    handle.dispose();
    host.resizeReader(key, initial);
    await flushResize(host, key);
    assert.strictEqual(
      calls,
      1,
      "a resize after disposal cannot reach the old lease"
    );
  });

  test("window host coalesces resize work on the popup animation frame", function (assert) {
    const host = hostFor(this);
    const key = "popup-resize-frame";
    const handle = opened(host, key, assert);
    const openingFrames = new Map();
    let nextFrame = 1;
    let calls = 0;
    sinon.stub(window, "requestAnimationFrame").callsFake((callback) => {
      const id = nextFrame++;
      openingFrames.set(id, callback);
      return id;
    });
    sinon.stub(window, "cancelAnimationFrame").callsFake((id) => {
      openingFrames.delete(id);
    });
    handle.onResize(() => calls++);

    host.resizeReader(key, host.measurementFor(key));
    host.resizeReader(key, host.measurementFor(key));
    host.resizeReader(key, host.measurementFor(key));
    host.flushPopupAnimationFrame(key);

    assert.strictEqual(
      calls,
      1,
      "the visible popup delivers exactly one callback without an opener frame"
    );
  });

  test("window host reader close updates closed and invokes pagehide", function (assert) {
    const host = hostFor(this);
    const key = "reader-close";
    const handle = opened(host, key, assert);
    let calls = 0;
    handle.onPagehide(() => calls++);

    host.closeAsReader(key);

    assert.true(
      handle.closed,
      "the handle observes the reader closing its window"
    );
    assert.strictEqual(calls, 1, "reader close reports pagehide once");
    handle.dispose();
    assert.strictEqual(
      host.closeCount(key),
      0,
      "disposing an already closed window does not close it again"
    );
  });

  test("window host keeps a bfcache lease mounted and resumes it in place", async function (assert) {
    const host = hostFor(this);
    const key = "bfcache-resume";
    const handle = opened(host, key, assert);
    // A handle only meets an unloading page once the panel has rendered
    // into its window; an uncommitted one is closed rather than handed on.
    handle.commit();
    const generation = handle.generation;
    const mount = handle.mount;
    let pagehideCalls = 0;
    let resizeCalls = 0;
    handle.onPagehide(() => pagehideCalls++);
    handle.onResize(() => resizeCalls++);

    host.fireOpenerPagehide(true);
    assert.false(
      handle.suspended,
      "bfcache does not turn ownership into reload suspension"
    );
    assert.strictEqual(
      handle.mount,
      mount,
      "the rendered mount remains in place"
    );
    assert
      .dom(NOTE_SELECTOR, mount.ownerDocument)
      .exists("the pause note is visible");

    host.resizeReader(key, host.measurementFor(key));
    host.navigateReader(key);
    await flushResize(host, key);
    assert.strictEqual(
      resizeCalls,
      0,
      "callbacks are paused while the opener is cached"
    );
    assert.strictEqual(pagehideCalls, 0, "pagehide callbacks are paused too");

    host.fireOpenerPageshow(true);
    host.fireOpenerPageshow(true);
    assert.strictEqual(
      handle.generation,
      generation,
      "resume keeps the same generation"
    );
    assert.strictEqual(
      handle.mount,
      mount,
      "resume keeps the same mount object"
    );
    assert
      .dom(NOTE_SELECTOR, mount.ownerDocument)
      .doesNotExist("the resume note clears");

    host.resizeReader(key, host.measurementFor(key));
    host.navigateReader(key);
    await flushResize(host, key);
    assert.strictEqual(
      resizeCalls,
      1,
      "callbacks are armed exactly once after resume"
    );
    assert.strictEqual(
      pagehideCalls,
      1,
      "pagehide is armed exactly once after resume"
    );
  });

  test("window host persisted pageshow does not resume a suspended handle", async function (assert) {
    const host = hostFor(this);
    const key = "suspended-after-pause";
    const handle = opened(host, key, assert);
    // A handle only meets an unloading page once the panel has rendered
    // into its window; an uncommitted one is closed rather than handed on.
    handle.commit();
    let pagehideCalls = 0;
    let resizeCalls = 0;
    handle.onPagehide(() => pagehideCalls++);
    handle.onResize(() => resizeCalls++);

    host.fireOpenerPagehide(true);
    host.fireOpenerPagehide(false);
    host.fireOpenerPageshow(true);

    assert.true(handle.suspended, "the real unload remains authoritative");
    assert
      .dom(NOTE_SELECTOR, handle.mount.ownerDocument)
      .exists("the handoff note remains visible");

    host.navigateReader(key);
    host.resizeReader(key, host.measurementFor(key));
    await flushResize(host, key);
    assert.strictEqual(
      pagehideCalls,
      0,
      "pageshow does not re-arm pagehide after handoff"
    );
    assert.strictEqual(
      resizeCalls,
      0,
      "pageshow does not re-arm resize after handoff"
    );
  });

  test("window host attempts every popup cleanup operation when listener removal throws", function (assert) {
    const host = hostFor(this);
    const key = "independent-popup-cleanup";
    const handle = opened(host, key, assert);
    handle.onResize(() => {});
    host.resizeReader(key, host.measurementFor(key));
    host.failWindowOperation(key, "removeEventListener:pagehide");

    host.fireOpenerPagehide(false);

    assert.deepEqual(
      [host.windowListenerCount(key, "resize"), host.animationFrameCount(key)],
      [0, 0],
      "resize listener removal and frame cancellation are still attempted"
    );
  });

  test("window host queued resize callbacks stay inert after every inactive transition when cancellation throws", function (assert) {
    const callsByTransition = [];

    for (const transition of ["pause", "suspend", "dispose"]) {
      const host = hostFor(this);
      const key = `failed-frame-cancellation-${transition}`;
      const handle = opened(host, key, assert);
      let calls = 0;
      handle.onResize(() => calls++);
      host.resizeReader(key, host.measurementFor(key));
      host.failWindowOperation(key, "cancelAnimationFrame");

      if (transition === "pause") {
        host.fireOpenerPagehide(true);
      } else if (transition === "suspend") {
        host.fireOpenerPagehide(false);
      } else {
        handle.dispose();
      }
      host.flushPopupAnimationFrame(key);
      callsByTransition.push(calls);
    }

    assert.deepEqual(
      callsByTransition,
      [0, 0, 0],
      "queued callbacks cannot run after pause, suspension, or disposal"
    );
  });

  test("window host ignores a queued resize frame after pause and resume when cancellation throws", function (assert) {
    const host = hostFor(this);
    const key = "failed-frame-cancellation-resume";
    const handle = opened(host, key, assert);
    let calls = 0;
    handle.onResize(() => calls++);
    host.resizeReader(key, host.measurementFor(key));
    host.failWindowOperation(key, "cancelAnimationFrame");

    host.fireOpenerPagehide(true);
    host.fireOpenerPageshow(true);
    host.flushPopupAnimationFrame(key);

    assert.strictEqual(
      calls,
      0,
      "the frame armed before pause stays stale after reporting resumes"
    );
  });

  test("window host stale resize frame cannot discard its successor", function (assert) {
    const host = hostFor(this);
    const key = "superseded-resize-frame";
    opened(host, key, assert);
    host.resizeReader(key, host.measurementFor(key));
    const staleFrame = host.popupAnimationFrameCallback(key);

    host.fireOpenerPagehide(true);
    host.fireOpenerPageshow(true);
    host.resizeReader(key, host.measurementFor(key));
    staleFrame(performance.now());
    host.resizeReader(key, host.measurementFor(key));

    assert.strictEqual(
      host.animationFrameCount(key),
      1,
      "the pending successor remains the only outstanding resize frame"
    );
  });

  test("window host dispose completes bookkeeping when window cleanup throws", function (assert) {
    for (const operation of ["removeEventListener", "close", "closed"]) {
      const firstHost = hostFor(this);
      const secondHost = hostFor(this);
      const key = `throwing-dispose-${operation}`;
      const handle = opened(firstHost, key, assert);
      let pagehideCalls = 0;
      let disposeError;
      handle.onPagehide(() => pagehideCalls++);
      firstHost.failWindowOperation(key, operation);

      try {
        handle.dispose();
      } catch (error) {
        disposeError = error;
      }
      firstHost.permitWindowOperation(key, operation);

      assert.strictEqual(
        disposeError,
        undefined,
        `${operation} errors do not escape dispose`
      );
      firstHost.navigateReader(key);
      assert.strictEqual(
        pagehideCalls,
        0,
        `${operation} errors do not retain handle callbacks`
      );
      assert.strictEqual(
        firstHost.listenerCount("pagehide"),
        0,
        `${operation} errors do not retain opener listeners`
      );
      assert.strictEqual(
        secondHost.open(key, STRINGS).status,
        "connecting",
        `${operation} errors do not retain the lease`
      );
    }
  });

  test("window host permanent pagehide suspends teardown without closing the window", function (assert) {
    const host = hostFor(this);
    const key = "reload-suspension";
    const handle = opened(host, key, assert);
    // A handle only meets an unloading page once the panel has rendered
    // into its window; an uncommitted one is closed rather than handed on.
    handle.commit();
    const panelWindow = host.windowFor(key);

    host.fireOpenerPagehide(false);
    assert.true(handle.suspended, "the old page marks its handle suspended");
    assert
      .dom(NOTE_SELECTOR, handle.mount.ownerDocument)
      .exists("the reload note is visible");

    handle.focus();
    handle.clearNote();
    handle.close();
    handle.dispose();
    handle.dispose();
    assert.strictEqual(
      host.focusCount,
      0,
      "a suspended handle cannot focus the window"
    );
    assert
      .dom(NOTE_SELECTOR, handle.mount.ownerDocument)
      .exists("its note cannot be cleared");
    assert.false(
      panelWindow.closed,
      "close and teardown leave the reader window standing"
    );
    assert.strictEqual(
      host.closeCount(key),
      0,
      "no close call reaches the suspended window"
    );

    const adopted = acquired(host.adopt(key, STRINGS), assert);
    assert.strictEqual(
      adopted.mount.ownerDocument.defaultView,
      panelWindow,
      "a following page can adopt the window teardown preserved"
    );
  });

  test("window host installs opener listeners only for the lifetime of its leases", function (assert) {
    const host = hostFor(this);
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "an idle host installs nothing"
    );
    assert.strictEqual(
      host.listenerCount("pageshow"),
      0,
      "an idle host installs nothing"
    );

    const first = opened(host, "listener-first", assert);
    assert.strictEqual(
      host.listenerCount("pagehide"),
      1,
      "the first lease installs pagehide"
    );
    assert.strictEqual(
      host.listenerCount("pageshow"),
      1,
      "the first lease installs pageshow"
    );

    const second = opened(host, "listener-second", assert);
    assert.strictEqual(
      host.listenerCount("pagehide"),
      1,
      "another lease reuses pagehide"
    );
    assert.strictEqual(
      host.listenerCount("pageshow"),
      1,
      "another lease reuses pageshow"
    );

    first.dispose();
    assert.strictEqual(
      host.listenerCount("pagehide"),
      1,
      "one remaining lease keeps listeners"
    );
    second.dispose();
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "the last lease removes pagehide"
    );
    assert.strictEqual(
      host.listenerCount("pageshow"),
      0,
      "the last lease removes pageshow"
    );
  });

  test("window host willDestroy releases every held window and lease", function (assert) {
    const host = hostFor(this);
    const first = opened(host, "destroy-first", assert);
    const second = opened(host, "destroy-second", assert);

    host.willDestroy();

    assert.true(first.closed, "the first held window closes");
    assert.true(second.closed, "the second held window closes");
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "host listeners are detached"
    );

    const replacement = hostFor(this);
    opened(replacement, "destroy-first", assert);
    opened(replacement, "destroy-second", assert);
  });

  test("window host owner destruction releases every held window and lease", async function (assert) {
    const popupHost = hostFor(this);
    const firstWindow = popupHost.seedBlankWindow("owner-destroy-first");
    const secondWindow = popupHost.seedBlankWindow("owner-destroy-second");
    const windowOpen = sinon.stub(window, "open");
    windowOpen.onFirstCall().returns(firstWindow);
    windowOpen.onSecondCall().returns(secondWindow);
    const owner = await buildOwner(null, getResolver());
    const addEventListener = sinon.spy(window, "addEventListener");
    const removeEventListener = sinon.spy(window, "removeEventListener");
    const host = windowHostFor(owner);
    connecting(host.open("owner-destroy-first", STRINGS), assert);
    connecting(host.open("owner-destroy-second", STRINGS), assert);
    const pagehideListener = addEventListener
      .getCalls()
      .find((call) => call.args[0] === "pagehide").args[1];
    let destroyError;

    try {
      owner.destroy();
      await settled();
    } catch (error) {
      destroyError = error;
    }

    assert.strictEqual(
      destroyError,
      undefined,
      "the real owner teardown completes"
    );
    assert.true(firstWindow.closed, "the first held window closes");
    assert.true(secondWindow.closed, "the second held window closes");
    assert.true(
      removeEventListener.calledWith("pagehide", pagehideListener),
      "owner teardown detaches its opener listener"
    );

    const replacement = hostFor(this);
    opened(replacement, "owner-destroy-first", assert);
    opened(replacement, "owner-destroy-second", assert);

    host.willDestroy();
  });

  test("window host lookup returns the pre-registered shared host for an owner", function (assert) {
    const registered = hostFor(this);
    this.owner.register(WINDOW_HOST_REGISTRATION, registered, {
      instantiate: false,
    });

    const firstLookup = windowHostFor(this.owner);
    const secondLookup = windowHostFor(this.owner);

    assert.strictEqual(
      firstLookup,
      registered,
      "the pre-registered test host wins"
    );
    assert.strictEqual(
      secondLookup,
      firstLookup,
      "the owner returns one shared host"
    );
    opened(firstLookup, "registered-host", assert);
  });

  /*
   * ---------------------------------------------------------------------------
   * Everything below covers the asynchronous open, where the window is a page
   * served at /panel-window/:key rather than a document the opener writes. None
   * of it can run until `IframeWindowHost` grows the controls specified here.
   * The double owns the clock and the poll queue; no test below waits on wall
   * time, and none of them may be made to pass with a timer.
   *
   * scheduleProbe(key, run) — an override of the seam `PanelWindowHostBase` uses
   *   to schedule its readiness probes, which in the browser is a 250ms timer.
   *   Queues `run` against `key`, returns a canceller, and never touches a real
   *   timer.
   *
   * tick(key) — runs exactly one queued probe, the way one turn of the budget
   *   would. Throws when nothing is queued, so a test cannot pass by ticking a
   *   connection that has already stopped probing.
   *
   * expireConnection(key) — ticks until the connection reports a failure, at
   *   most 200 times. Throws if it resolved instead, or never failed.
   *
   * finishLoad(key) — the served shell arrives. Replaces the window's document
   *   with the markup the route serves: `<html data-d-panel-dock="<key>">` around
   *   a `.d-panel-dock-window` holding `.d-panel-dock-window__mount`, the hidden
   *   `.d-panel-dock-window__reconnecting` note with its `[role="status"]`
   *   sentence, and the float outlets. It must also drop every listener
   *   registered on that window beforehand, because a navigation replaces the
   *   global they were registered on. The window object itself stays the same,
   *   as a real named window does.
   *
   * loadForeignPage(key) — the window finishes loading something that is not the
   *   shell: a login redirect, a 404. Readable, arrived, and carrying no marker.
   *   Whatever the host tells "still loading" from "arrived" on, this must read
   *   as arrived; a window that has merely not loaded yet must not.
   *
   * makeDocumentUnreachable(key) — reading the window's `document` throws, the
   *   way a cross-origin navigation makes it.
   *
   * announceReady(key, { source }) — dispatches on `openerEvents` the `message`
   *   the served shell posts once it has rendered. `source` defaults to that
   *   window; passing another forges the one thing the host has to check.
   *
   * resolveWindow(key, resolution) — the new signature. Records every resolution
   *   in `resolutions`, in order. `{ intent: "adopt" }` returns the named window
   *   untouched and navigates nothing; `{ intent: "open", url, geometry }`
   *   creates a window whose document has not loaded yet.
   *
   * Three existing behaviours have to follow: `#remember` must follow a
   * `connecting` outcome through `onReady`, so the handle it delivers is still
   * counted by `disposeCount`, still honours `makeMountUnavailable`, and is
   * still released by `teardown`; `teardown` must cancel connections that never
   * resolved; and `seedPreparedWindow` must write the served shell markup rather
   * than the skeleton the opener used to write.
   * ---------------------------------------------------------------------------
   */

  test("window host connecting refuses a blocked open without taking a lease", function (assert) {
    const host = hostFor(this);
    const key = "connecting-blocked";
    host.armNextResolveRefusal();

    assert.deepEqual(
      host.open(key, STRINGS),
      { status: "unavailable" },
      "a refused window is unavailable rather than connecting"
    );
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "a refusal leaves no opener listener behind"
    );

    const retry = connecting(host.open(key, STRINGS), assert);
    assert.strictEqual(
      host.resolveCount,
      2,
      "the refusal left the key free to ask for again"
    );
    retry.cancel();
  });

  test("window host connecting holds its key from the moment it is asked for", function (assert) {
    const host = hostFor(this);
    const contender = hostFor(this);
    const key = "connecting-second-open";
    const first = connecting(host.open(key, STRINGS), assert);

    assert.deepEqual(
      contender.open(key, STRINGS),
      { status: "already-leased" },
      "a window still loading is as leased as one that arrived"
    );
    assert.strictEqual(
      contender.resolveCount,
      0,
      "the competing request changes no browser state"
    );

    first.cancel();
    assert.strictEqual(
      contender.open(key, STRINGS).status,
      "connecting",
      "cancelling the first releases the key"
    );
  });

  test("window host connecting spends one tick at a time until the budget runs out", function (assert) {
    const host = hostFor(this);
    const contender = hostFor(this);
    const key = "connecting-timeout";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    for (let index = 0; index < 59; index++) {
      host.tick(key);
    }

    assert.deepEqual(events.failed, [], "59 ticks leave the connection alive");
    assert.strictEqual(
      host.closeCount(key),
      0,
      "a window that has not finished loading is not abandoned"
    );

    host.tick(key);

    assert.deepEqual(events.failed, ["timeout"], "the sixtieth tick ends it");
    assert.deepEqual(events.ready, [], "a timed-out connection never resolves");
    assert.strictEqual(
      host.closeCount(key),
      1,
      "the window nothing arrived in is closed once"
    );
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "the host stops listening to the opener"
    );
    assert.strictEqual(
      contender.open(key, STRINGS).status,
      "connecting",
      "the lease is free again"
    );
  });

  test("window host connecting fails as foreign when the window loads another page", function (assert) {
    for (const arrival of ["loadForeignPage", "makeDocumentUnreachable"]) {
      const host = hostFor(this);
      const contender = hostFor(this);
      const key = `connecting-foreign-${arrival}`;
      const events = watch(connecting(host.open(key, STRINGS), assert));

      host[arrival](key);
      host.tick(key);

      assert.deepEqual(
        events.failed,
        ["foreign"],
        `${arrival} is recognized as somebody else's page`
      );
      assert.deepEqual(events.ready, [], `${arrival} resolves nothing`);
      assert.strictEqual(
        host.closeCount(key),
        1,
        `${arrival} leaves no window standing`
      );
      assert.strictEqual(
        contender.open(key, STRINGS).status,
        "connecting",
        `${arrival} frees the lease`
      );
    }
  });

  test("window host connecting fails as closed when the reader closes the pending window", function (assert) {
    const host = hostFor(this);
    const contender = hostFor(this);
    const key = "connecting-reader-close";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    host.closeAsReader(key);
    host.tick(key);

    assert.deepEqual(events.failed, ["closed"], "the reader had the last word");
    assert.deepEqual(events.ready, [], "a closed window resolves nothing");
    assert.strictEqual(
      host.closeCount(key),
      0,
      "a window the reader already closed is not closed again"
    );
    assert.strictEqual(
      contender.open(key, STRINGS).status,
      "connecting",
      "the lease is free again"
    );
  });

  test("window host connecting takes the shell message as a hint, not as the answer", function (assert) {
    const host = hostFor(this);
    const key = "connecting-message-hint";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    host.announceReady(key);
    assert.deepEqual(
      events.ready,
      [],
      "a message that arrives before the document is the shell proves nothing"
    );

    host.finishLoad(key);
    host.announceReady(key);

    assert.strictEqual(
      events.ready.length,
      1,
      "the message resolves the loaded shell without spending a tick"
    );
    assert.strictEqual(
      shellKey(events.ready[0].mount.ownerDocument),
      key,
      "what was adopted is the shell the route served"
    );

    host.announceReady(key);
    assert.strictEqual(
      events.ready.length,
      1,
      "a repeated message cannot resolve the same connection twice"
    );
  });

  test("window host connecting spends no budget on shell messages", function (assert) {
    const host = hostFor(this);
    const key = "connecting-message-budget";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    for (let index = 0; index < 20; index++) {
      host.announceReady(key);
    }
    for (let index = 0; index < 59; index++) {
      host.tick(key);
    }

    assert.deepEqual(
      events.failed,
      [],
      "messages the probe could not confirm cost the connection nothing"
    );

    host.tick(key);
    assert.deepEqual(
      events.failed,
      ["timeout"],
      "the budget is still exactly sixty ticks long"
    );
  });

  test("window host connecting ignores a ready message from another window", function (assert) {
    const host = hostFor(this);
    const key = "connecting-message-source";
    const events = watch(connecting(host.open(key, STRINGS), assert));
    const bystander = host.seedBlankWindow("connecting-message-bystander");
    host.finishLoad(key);

    host.announceReady(key, { source: bystander });
    assert.deepEqual(
      events.ready,
      [],
      "a message from a window we did not open is not ours to act on"
    );

    host.tick(key);
    assert.strictEqual(
      events.ready.length,
      1,
      "the probe still finds the shell the forged message spoke for"
    );
  });

  test("window host connecting resolves an open by url and an adopt by name alone", function (assert) {
    const host = hostFor(this);
    const openKey = "connecting-open-intent";
    const adoptKey = "connecting-adopt-intent";
    const geometry = { width: 731, height: 487, left: 113, top: 79 };
    host.seedPreparedWindow(adoptKey, adoptKey);

    const connection = connecting(
      host.open(openKey, STRINGS, geometry),
      assert
    );
    const handle = acquired(host.adopt(adoptKey, STRINGS), assert);

    assert.strictEqual(
      handle.mount.ownerDocument.defaultView,
      host.windowFor(adoptKey),
      "adoption is still answered synchronously, out of the window itself"
    );
    assert.deepEqual(
      host.resolutions[1],
      { intent: "adopt" },
      "an adoption carries nothing that could navigate the window it takes over"
    );
    assert.strictEqual(host.resolutions[0].intent, "open", "an open navigates");
    assert.true(
      host.resolutions[0].url.endsWith(`/panel-window/${openKey}`),
      "an open is sent to the route serving this context"
    );
    assert.deepEqual(
      host.resolutions[0].geometry,
      geometry,
      "the remembered rectangle still reaches the browser"
    );
    connection.cancel();
  });

  test("window host connecting focuses the window on its way and keeps one lease generation", function (assert) {
    const host = hostFor(this);
    const key = "connecting-focus";
    const connection = connecting(host.open(key, STRINGS), assert);
    const events = watch(connection);

    connection.focus();
    connection.focus();
    assert.strictEqual(
      host.focusCount,
      2,
      "each request reaches the window that is still loading"
    );

    host.finishLoad(key);
    host.tick(key);

    assert.strictEqual(events.ready.length, 1, "the connection resolves");
    assert.strictEqual(
      events.ready[0].generation,
      connection.generation,
      "the handle continues the lease the connection took, rather than a new one"
    );

    events.ready[0].dispose();
    const replacement = connecting(host.open(key, STRINGS), assert);
    assert.true(
      replacement.generation > connection.generation,
      "a later connection never reuses a generation"
    );
  });

  test("window host connecting arms the window's own events only once its shell has loaded", async function (assert) {
    const host = hostFor(this);
    const key = "connecting-listen-after-load";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    host.finishLoad(key);
    host.tick(key);

    assert.strictEqual(events.ready.length, 1, "the connection resolves");
    const handle = events.ready[0];
    let pagehideCalls = 0;
    let resizeCalls = 0;
    handle.onPagehide(() => pagehideCalls++);
    handle.onResize(() => resizeCalls++);

    host.resizeReader(key, host.measurementFor(key));
    host.navigateReader(key);
    await flushResize(host, key);

    assert.strictEqual(
      pagehideCalls,
      1,
      "the load that replaced the window's global did not take the pagehide listener with it"
    );
    assert.strictEqual(resizeCalls, 1, "nor the resize listener");
  });

  test("window host connecting cancel closes the window and stops probing", function (assert) {
    const host = hostFor(this);
    const contender = hostFor(this);
    const key = "connecting-cancel";
    const connection = connecting(host.open(key, STRINGS), assert);
    const events = watch(connection);

    connection.cancel();
    connection.cancel();

    assert.strictEqual(
      host.closeCount(key),
      1,
      "the abandoned window is closed exactly once"
    );
    assert.deepEqual(
      events.ready,
      [],
      "a cancelled connection resolves nothing"
    );
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "the host stops listening to the opener"
    );
    assert.throws(
      () => host.tick(key),
      "a cancelled connection has nothing left to probe"
    );
    assert.strictEqual(
      contender.open(key, STRINGS).status,
      "connecting",
      "the lease is free again"
    );
  });

  test("window host connecting closes a window the opener unloads for good before it arrives", function (assert) {
    const host = hostFor(this);
    const contender = hostFor(this);
    const key = "connecting-opener-unload";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    host.fireOpenerPagehide(false);

    // Nothing has recorded this window yet, so leaving it standing would strand
    // it: no page that follows has any reason to adopt it.
    assert.strictEqual(
      host.closeCount(key),
      1,
      "a window nothing knows about is closed rather than handed on"
    );
    assert.deepEqual(events.ready, [], "the connection never resolves");
    assert.strictEqual(
      contender.open(key, STRINGS).status,
      "connecting",
      "the lease is free again"
    );
  });

  test("window host connecting survives an opener bfcache round trip", function (assert) {
    const host = hostFor(this);
    const key = "connecting-bfcache";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    host.fireOpenerPagehide(true);
    assert.strictEqual(
      host.closeCount(key),
      0,
      "a suspended opener keeps the window it is waiting for"
    );
    assert.deepEqual(events.failed, [], "being cached is not a failure");

    host.fireOpenerPageshow(true);
    host.finishLoad(key);
    host.tick(key);

    assert.strictEqual(
      events.ready.length,
      1,
      "the connection still completes once the opener comes back"
    );
  });

  test("window host connecting is released when its owner destroys the host", function (assert) {
    const host = hostFor(this);
    const contender = hostFor(this);
    const key = "connecting-host-destroy";
    const events = watch(connecting(host.open(key, STRINGS), assert));

    // The name the container calls, which is not the one the rest of the
    // codebase reads as "let go of your resources".
    host.destroy();

    assert.strictEqual(
      host.closeCount(key),
      1,
      "the pending window goes with the host"
    );
    assert.deepEqual(
      events.ready,
      [],
      "nothing is delivered to a caller that no longer exists"
    );
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "the opener listener is detached"
    );
    assert.strictEqual(
      contender.open(key, STRINGS).status,
      "connecting",
      "the lease is free again"
    );
  });
});
