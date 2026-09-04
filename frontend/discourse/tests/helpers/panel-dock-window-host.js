import { PanelWindowHostBase } from "discourse/ui-kit/panel-dock/-internals/window-host";
import { writeSkeleton } from "discourse/ui-kit/panel-dock/-internals/window-skeleton";

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

  #acquiredHandles = new Set();
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

  seedPreparedWindow(name, key, title = "Previously prepared panel") {
    const record = this.#createWindow(name);
    const skeleton = writeSkeleton(record.window.document, key, title);
    skeleton.dispose();
    return { mount: skeleton.mount, window: record.window };
  }

  setMeasurement(name, geometry) {
    this.#recordFor(name).geometry = { ...geometry };
  }

  teardown() {
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

  resolveWindow(name, geometry) {
    this.resolveCount++;

    if (this.#nextResolveRefused) {
      this.#nextResolveRefused = false;
      return null;
    }

    let record = this.#windows.get(name);
    if (!record || record.closed) {
      record = this.#createWindow(name, geometry);
    } else if (geometry) {
      record.geometry = { ...geometry };
    }

    return record.window;
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
      window: frame.contentWindow,
    };

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

  #remember(outcome, name) {
    if (outcome.status === "acquired") {
      if (this.#mountlessWindows.delete(name)) {
        Object.defineProperty(outcome.handle, "mount", { value: null });
      }

      const record = this.#recordFor(name);
      const dispose = outcome.handle.dispose.bind(outcome.handle);
      outcome.handle.dispose = () => {
        record.disposeCalls++;
        dispose();
      };
      this.#acquiredHandles.add(outcome.handle);
    }
    return outcome;
  }
}
