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
import { skeletonKey } from "discourse/ui-kit/panel-dock/-internals/window-skeleton";

const STRINGS = Object.freeze({
  title: "Window host oracle",
  note: {
    title: "The opening page went away",
    body: "Reload it to reconnect this panel.",
  },
});

const NOTE_SELECTOR = "main.d-panel-dock-window__reconnecting";

function acquired(outcome, assert) {
  assert.strictEqual(outcome.status, "acquired", "the lease is acquired");
  return outcome.handle;
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

    const handle = acquired(host.open(key, STRINGS, measured), assert);

    assert.deepEqual(
      handle.measure(),
      measured,
      "the geometry comes from the caller without accidental clamping"
    );
    assert.strictEqual(
      skeletonKey(handle.mount.ownerDocument),
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

    const retry = acquired(host.open("blocked-window", STRINGS), assert);
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
    const first = acquired(firstHost.open(key, STRINGS), assert);

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
    const stale = acquired(firstHost.open(key, STRINGS), assert);
    firstHost.closeAsReader(key);

    const outcome = secondHost.open(key, STRINGS);
    const replacementClosed = outcome.handle?.closed;

    assert.true(stale.closed, "the stale handle observes its closed window");
    assert.strictEqual(outcome.status, "acquired", "open reclaims the lease");
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
    acquired(firstHost.open(key, STRINGS), assert);
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
    const first = acquired(owner.open(key, STRINGS), assert);
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
    assert.notStrictEqual(
      handle.mount,
      previous.mount,
      "adoption creates a new mount for the new page"
    );
    assert.false(previous.mount.isConnected, "the orphaned tree is removed");
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

    const retry = acquired(host.open(key, STRINGS), assert);
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

    const handle = acquired(host.open(key, STRINGS), assert);

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
      skeletonKey(handle.mount.ownerDocument),
      key,
      "the new key wins"
    );
  });

  test("window host generations increase and an old double-dispose cannot release a new lease", function (assert) {
    const firstHost = hostFor(this);
    const secondHost = hostFor(this);
    const thirdHost = hostFor(this);
    const key = "generation-guard";
    const first = acquired(firstHost.open(key, STRINGS), assert);
    first.dispose();
    const second = acquired(secondHost.open(key, STRINGS), assert);

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
    const third = acquired(thirdHost.open(key, STRINGS), assert);
    assert.true(
      third.generation > second.generation,
      "a later successful lease never reuses a generation"
    );
  });

  test("window host focuses and measures the live window while preserving a good measurement", function (assert) {
    const host = hostFor(this);
    const key = "focus-and-measure";
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
    const mount = handle.mount;
    const doc = mount.ownerDocument;

    handle.showNote();
    assert.dom(NOTE_SELECTOR, doc).exists("the lease note is shown");
    assert
      .dom(`${NOTE_SELECTOR} .empty-state__title`, doc)
      .hasText(STRINGS.note.title, "the resolved note title is used");
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
      const handle = acquired(host.open(key, STRINGS), assert);
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
    const handle = acquired(host.open(key, STRINGS), assert);
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
    acquired(host.open(key, STRINGS), assert);
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
      const handle = acquired(firstHost.open(key, STRINGS), assert);
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
        "acquired",
        `${operation} errors do not retain the lease`
      );
    }
  });

  test("window host permanent pagehide suspends teardown without closing the window", function (assert) {
    const host = hostFor(this);
    const key = "reload-suspension";
    const handle = acquired(host.open(key, STRINGS), assert);
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

    const first = acquired(host.open("listener-first", STRINGS), assert);
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

    const second = acquired(host.open("listener-second", STRINGS), assert);
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
    const first = acquired(host.open("destroy-first", STRINGS), assert);
    const second = acquired(host.open("destroy-second", STRINGS), assert);

    host.willDestroy();

    assert.true(first.closed, "the first held window closes");
    assert.true(second.closed, "the second held window closes");
    assert.strictEqual(
      host.listenerCount("pagehide"),
      0,
      "host listeners are detached"
    );

    const replacement = hostFor(this);
    acquired(replacement.open("destroy-first", STRINGS), assert);
    acquired(replacement.open("destroy-second", STRINGS), assert);
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
    acquired(host.open("owner-destroy-first", STRINGS), assert);
    acquired(host.open("owner-destroy-second", STRINGS), assert);
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
    acquired(replacement.open("owner-destroy-first", STRINGS), assert);
    acquired(replacement.open("owner-destroy-second", STRINGS), assert);

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
    acquired(firstLookup.open("registered-host", STRINGS), assert);
  });
});
