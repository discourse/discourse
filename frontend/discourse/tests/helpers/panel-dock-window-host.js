import {
  writeForeignPage,
  writeShellFixture,
} from "discourse/tests/helpers/panel-dock-window-shell";
import { PanelWindowHostBase } from "discourse/ui-kit/panel-dock/-internals/window-host";

const DEFAULT_GEOMETRY = Object.freeze({
  width: 731,
  height: 487,
  left: 113,
  top: 79,
});

/** An EventTarget that exposes whether production listeners remain attached. */
class TrackedEventTarget extends EventTarget {
  #listeners = new Map();

  addEventListener(type, callback, options) {
    super.addEventListener(type, callback, options);
    this.#listenersFor(type).add(callback);
  }

  removeEventListener(type, callback, options) {
    super.removeEventListener(type, callback, options);
    this.#listenersFor(type).delete(callback);
  }

  listenerCount(type) {
    return this.#listenersFor(type).size;
  }

  #listenersFor(type) {
    if (!this.#listeners.has(type)) {
      this.#listeners.set(type, new Set());
    }

    return this.#listeners.get(type);
  }
}

/** A same-origin browser-window seam for exercising the real host lifecycle. */
export class IframeWindowHost extends PanelWindowHostBase {
  adoptCount = 0;
  adoptKeys = [];
  focusCount = 0;
  openCount = 0;
  openKeys = [];
  resolveCount = 0;
  resolutions = [];

  #acquiredHandles = new Set();
  #connections = new Set();
  #frames = [];
  #mountlessWindows = new Set();
  #nextResolveRefused = false;
  #openerEvents = new TrackedEventTarget();
  #windows = new Map();

  get openerEvents() {
    return this.#openerEvents;
  }

  adopt(key, strings) {
    this.adoptCount++;
    this.adoptKeys.push(key);
    return this.#remember(super.adopt(key, strings), key);
  }

  animationFrameCount(name) {
    return this.#recordFor(name).animationFrames.size;
  }

  armNextResolveRefusal() {
    this.#nextResolveRefused = true;
  }

  closeAsReader(name) {
    const record = this.#recordFor(name);
    record.closed = true;
    record.window.dispatchEvent(this.#pageTransitionEvent(record, false));
  }

  closeCount(name) {
    return this.#recordFor(name).closeCalls;
  }

  disposeCount(name) {
    return this.#recordFor(name).disposeCalls;
  }

  failWindowOperation(name, operation) {
    this.#recordFor(name).failingOperations.add(operation);
  }

  fireOpenerPagehide(persisted) {
    this.#openerEvents.dispatchEvent(
      this.#openerTransitionEvent("pagehide", persisted)
    );
  }

  fireOpenerPageshow(persisted) {
    this.#openerEvents.dispatchEvent(
      this.#openerTransitionEvent("pageshow", persisted)
    );
  }

  flushPopupAnimationFrame(name) {
    const record = this.#recordFor(name);
    const callbacks = [...record.animationFrames.values()];
    record.animationFrames.clear();

    callbacks.forEach((callback) => callback(performance.now()));
  }

  listenerCount(type) {
    return this.#openerEvents.listenerCount(type);
  }

  permitWindowOperation(name, operation) {
    this.#recordFor(name).failingOperations.delete(operation);
  }

  popupAnimationFrameCallback(name) {
    const record = this.#recordFor(name);
    return record.animationFrames.values().next().value;
  }

  measurementFor(name) {
    return { ...this.#recordFor(name).geometry };
  }

  measureCount(name) {
    return this.#recordFor(name).measureCalls;
  }

  makeMountUnavailable(name) {
    this.#mountlessWindows.add(name);
  }

  navigateReader(name) {
    const record = this.#recordFor(name);
    record.window.dispatchEvent(this.#pageTransitionEvent(record, false));
  }

  open(key, strings, geometry) {
    this.openCount++;
    this.openKeys.push(key);
    return this.#remember(super.open(key, strings, geometry), key);
  }

  reportZeroMeasurement(name) {
    this.setMeasurement(name, { width: 0, height: 0, left: 0, top: 0 });
  }

  resizeReader(name, geometry) {
    this.setMeasurement(name, geometry);
    const panelWindow = this.#recordFor(name).window;
    panelWindow.dispatchEvent(new panelWindow.Event("resize"));
  }

  seedBlankWindow(name) {
    return this.#createWindow(name).window;
  }

  seedPreparedWindow(name, key) {
    const record = this.#createWindow(name);
    const { mount } = writeShellFixture(record.window.document, key);
    record.arrived = true;
    return { mount, window: record.window };
  }

  setMeasurement(name, geometry) {
    this.#recordFor(name).geometry = { ...geometry };
  }

  teardown() {
    for (const connection of this.#connections) {
      connection.cancel();
    }
    this.#connections.clear();

    for (const handle of this.#acquiredHandles) {
      handle.dispose();
    }
    this.#acquiredHandles.clear();

    for (const frame of this.#frames) {
      frame.remove();
    }
    this.#frames.length = 0;
    this.#windows.clear();
  }

  windowFor(name) {
    return this.#recordFor(name).window;
  }

  windowListenerCount(name, type) {
    return this.#recordFor(name).listeners.get(type)?.size ?? 0;
  }

  resolveWindow(name, resolution) {
    this.resolveCount++;
    this.resolutions.push(resolution);

    if (this.#nextResolveRefused) {
      this.#nextResolveRefused = false;
      return null;
    }

    const existing = this.#windows.get(name);

    // Adopting reveals whatever is already under the name and navigates
    // nothing, which is the whole reason it can answer synchronously.
    if (resolution.intent === "adopt") {
      return (
        existing && !existing.closed ? existing : this.#createWindow(name)
      ).window;
    }

    const geometry = resolution.geometry;
    let record = existing;

    if (!record || record.closed) {
      record = this.#createWindow(name, geometry);
    } else if (geometry) {
      record.geometry = { ...geometry };
    }

    // Opening navigates, so whatever was in it is on its way out.
    record.arrived = false;
    return record.window;
  }

  /**
   * `Window.document` is unforgeable, so a window that has gone somewhere we
   * cannot look is expressed here rather than on the window itself.
   */
  readDocument(panelWindow) {
    for (const record of this.#windows.values()) {
      if (record.window === panelWindow && record.unreachable) {
        return null;
      }
    }

    return super.readDocument(panelWindow);
  }

  /** The seam the host schedules readiness probes through. */
  scheduleProbe(name, run) {
    const record = this.#recordFor(name);
    const entry = { run };
    record.probes.push(entry);

    return () => {
      const at = record.probes.indexOf(entry);
      if (at !== -1) {
        record.probes.splice(at, 1);
      }
    };
  }

  /** Runs exactly one queued probe, the way one turn of the budget would. */
  tick(name) {
    const record = this.#recordFor(name);
    const entry = record.probes.shift();

    if (!entry) {
      throw new Error(
        `no probe is queued for "${name}"; the connection has stopped looking`
      );
    }

    entry.run();
  }

  /** Ticks until the connection gives up, so a test never counts by hand. */
  expireConnection(name) {
    const record = this.#recordFor(name);

    for (let spent = 0; spent < 200; spent++) {
      if (record.probes.length === 0) {
        return;
      }

      this.tick(name);
    }

    throw new Error(`"${name}" never stopped probing`);
  }

  /** The served shell arrives in the window. */
  finishLoad(name) {
    const record = this.#recordFor(name);

    // A navigation replaces the window's global, so anything registered on the
    // one that was there before it is gone. Nothing that survives that in the
    // double would survive it in a browser.
    for (const [type, callbacks] of record.listeners) {
      for (const callback of callbacks) {
        record.window.removeEventListener(type, callback);
      }
      callbacks.clear();
    }

    writeShellFixture(record.window.document, name);
    record.arrived = true;
  }

  /** The window finishes loading something that is not the shell. */
  loadForeignPage(name) {
    const record = this.#recordFor(name);
    writeForeignPage(record.window.document);
    record.arrived = true;
  }

  /** Reading the window's document throws, as a cross-origin hop makes it. */
  makeDocumentUnreachable(name) {
    this.#recordFor(name).unreachable = true;
  }

  /** The message the served shell posts once it has rendered. */
  announceReady(name, { source } = {}) {
    const record = this.#recordFor(name);
    const event = new MessageEvent("message", {
      data: { type: "d-panel-dock:ready", key: name },
    });

    // `source` is read-only on a constructed MessageEvent, and forging it is
    // exactly what one of these tests needs to do.
    Object.defineProperty(event, "source", {
      configurable: true,
      value: source === undefined ? record.window : source,
    });

    this.openerEvents.dispatchEvent(event);
  }

  #createWindow(name, geometry = DEFAULT_GEOMETRY) {
    const frame = document.createElement("iframe");
    frame.setAttribute("aria-hidden", "true");
    frame.name = name;
    frame.style.width = "1px";
    frame.style.height = "1px";
    document.body.appendChild(frame);

    const record = {
      animationFrames: new Map(),
      closeCalls: 0,
      closed: false,
      disposeCalls: 0,
      failingOperations: new Set(),
      frame,
      geometry: { ...(geometry ?? DEFAULT_GEOMETRY) },
      listeners: new Map(),
      measureCalls: 0,
      nextAnimationFrame: 1,
      probes: [],
      arrived: false,
      unreachable: false,
      window: frame.contentWindow,
    };

    // What the host tells "still on its way" from "arrived somewhere". A real
    // window sits on a blank document until its navigation commits; an iframe
    // written into by hand never changes URL, so the double says so explicitly.
    Object.defineProperties(record.window.document, {
      URL: {
        configurable: true,
        get: () => (record.arrived ? "/panel-window/served" : "about:blank"),
      },
      readyState: {
        configurable: true,
        get: () => (record.arrived ? "complete" : "loading"),
      },
    });

    const addEventListener = record.window.addEventListener.bind(record.window);
    const removeEventListener = record.window.removeEventListener.bind(
      record.window
    );

    Object.defineProperties(record.window, {
      addEventListener: {
        configurable: true,
        value: (type, callback, options) => {
          addEventListener(type, callback, options);

          if (!record.listeners.has(type)) {
            record.listeners.set(type, new Set());
          }
          record.listeners.get(type).add(callback);
        },
      },
      cancelAnimationFrame: {
        configurable: true,
        value: (id) => {
          if (record.failingOperations.has("cancelAnimationFrame")) {
            throw new Error("cancelAnimationFrame failed");
          }

          record.animationFrames.delete(id);
        },
      },
      close: {
        configurable: true,
        value: () => {
          if (record.failingOperations.has("close")) {
            throw new Error("close failed");
          }

          record.closeCalls++;
          record.closed = true;
        },
      },
      closed: {
        configurable: true,
        get: () => {
          if (record.failingOperations.has("closed")) {
            throw new Error("closed read failed");
          }

          return record.closed;
        },
      },
      focus: {
        configurable: true,
        value: () => this.focusCount++,
      },
      outerHeight: {
        configurable: true,
        get: () => record.geometry.height,
      },
      outerWidth: {
        configurable: true,
        get: () => {
          record.measureCalls++;
          return record.geometry.width;
        },
      },
      removeEventListener: {
        configurable: true,
        value: (type, callback, options) => {
          if (
            record.failingOperations.has("removeEventListener") ||
            record.failingOperations.has(`removeEventListener:${type}`)
          ) {
            throw new Error("removeEventListener failed");
          }

          removeEventListener(type, callback, options);
          record.listeners.get(type)?.delete(callback);
        },
      },
      requestAnimationFrame: {
        configurable: true,
        value: (callback) => {
          const id = record.nextAnimationFrame++;
          record.animationFrames.set(id, callback);
          return id;
        },
      },
      screenLeft: {
        configurable: true,
        get: () => record.geometry.left,
      },
      screenTop: {
        configurable: true,
        get: () => record.geometry.top,
      },
      screenX: {
        configurable: true,
        get: () => record.geometry.left,
      },
      screenY: {
        configurable: true,
        get: () => record.geometry.top,
      },
    });

    this.#frames.push(frame);
    this.#windows.set(name, record);
    return record;
  }

  #openerTransitionEvent(type, persisted) {
    const event = new Event(type);
    Object.defineProperty(event, "persisted", { value: persisted });
    return event;
  }

  #pageTransitionEvent(record, persisted) {
    const event = new record.window.Event("pagehide");
    Object.defineProperty(event, "persisted", { value: persisted });
    return event;
  }

  #recordFor(name) {
    const record = this.#windows.get(name);
    if (!record) {
      throw new Error(`No iframe window named ${name}`);
    }

    return record;
  }

  /** Counts a handle the way the double's assertions expect, however it arrived. */
  #track(handle, name) {
    if (this.#mountlessWindows.delete(name)) {
      Object.defineProperty(handle, "mount", { value: null });
    }

    const record = this.#recordFor(name);
    const dispose = handle.dispose.bind(handle);
    handle.dispose = () => {
      record.disposeCalls++;
      dispose();
    };
    this.#acquiredHandles.add(handle);
  }

  #remember(outcome, name) {
    if (outcome.status === "acquired") {
      this.#track(outcome.handle, name);
      return outcome;
    }

    // A connection is not a handle yet, so it is followed rather than tracked:
    // whatever it becomes still has to be counted, still has to honour a
    // withheld mount, and still has to be released by teardown.
    if (outcome.status === "connecting") {
      this.#connections.add(outcome.connection);
      outcome.connection.onReady((handle) => {
        this.#connections.delete(outcome.connection);
        this.#track(handle, name);
      });
      outcome.connection.onFailed(() =>
        this.#connections.delete(outcome.connection)
      );
    }

    return outcome;
  }
}
