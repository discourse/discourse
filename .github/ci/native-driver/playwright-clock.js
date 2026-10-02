
var __commonJS = obj => {
  let required = false;
  let result;
  return function __require() {
    if (!required) {
      required = true;
      let fn;
      for (const name in obj) { fn = obj[name]; break; }
      const module = { exports: {} };
      fn(module.exports, module);
      result = module.exports;
    }
    return result;
  }
};
var __export = (target, all) => {for (var name in all) target[name] = all[name];};
var __toESM = mod => ({ ...mod, 'default': mod });
var __toCommonJS = mod => ({ ...mod, __esModule: true });


// packages/injected/src/clock.ts
var clock_exports = {};
__export(clock_exports, {
  ClockController: () => ClockController,
  createClock: () => createClock,
  inject: () => inject,
  install: () => install
});
module.exports = __toCommonJS(clock_exports);
var ClockController = class {
  constructor(embedder) {
    this._duringTick = false;
    this._uniqueTimerId = idCounterStart;
    this.disposables = [];
    this._log = [];
    this._timers = /* @__PURE__ */ new Map();
    this._now = { time: asWallTime(0), isFixedTime: false, ticks: 0, origin: asWallTime(-1) };
    this._embedder = embedder;
  }
  uninstall() {
    this.disposables.forEach((dispose) => dispose());
    this.disposables.length = 0;
  }
  now() {
    this._replayLogOnce();
    this._syncRealTime();
    return this._now.time;
  }
  install(time) {
    this._replayLogOnce();
    this._innerInstall(asWallTime(time));
  }
  setSystemTime(time) {
    this._replayLogOnce();
    this._innerSetTime(asWallTime(time));
  }
  setFixedTime(time) {
    this._replayLogOnce();
    this._innerSetFixedTime(asWallTime(time));
  }
  performanceNow() {
    this._replayLogOnce();
    this._syncRealTime();
    return this._now.ticks;
  }
  _syncRealTime() {
    if (!this._realTime)
      return;
    const now = this._embedder.performanceNow();
    const sinceLastSync = now - this._realTime.lastSyncTicks;
    if (sinceLastSync > 0) {
      this._advanceNow(shiftTicks(this._now.ticks, sinceLastSync));
      this._realTime.lastSyncTicks = now;
    }
  }
  _innerSetTime(time) {
    this._now.time = time;
    this._now.isFixedTime = false;
    if (this._now.origin < 0)
      this._now.origin = this._now.time;
  }
  _innerInstall(time) {
    if (this._now.origin < 0)
      this._now.ticks = 0;
    this._innerSetTime(time);
  }
  _innerSetFixedTime(time) {
    this._innerSetTime(time);
    this._now.isFixedTime = true;
  }
  _advanceNow(to) {
    if (this._now.ticks > to) {
      return;
    }
    if (!this._now.isFixedTime)
      this._now.time = asWallTime(this._now.time + to - this._now.ticks);
    this._now.ticks = to;
  }
  async log(type, time, param) {
    this._log.push({ type, time, param });
  }
  async runFor(ticks) {
    this._replayLogOnce();
    if (ticks < 0)
      throw new TypeError("Negative ticks are not supported");
    await this._runWithDisabledRealTimeSync(async () => {
      await this._runTo(shiftTicks(this._now.ticks, ticks));
    });
  }
  async _runTo(to) {
    to = Math.ceil(to);
    if (this._now.ticks > to)
      return;
    let firstException;
    while (true) {
      const result = await this._callFirstTimer(to);
      if (!result.timerFound)
        break;
      firstException = firstException || result.error;
    }
    this._advanceNow(to);
    if (firstException)
      throw firstException;
  }
  async pauseAt(time) {
    this._replayLogOnce();
    await this._innerPause();
    const toConsume = time - this._now.time;
    await this._innerFastForwardTo(shiftTicks(this._now.ticks, toConsume));
    return toConsume;
  }
  async _innerPause() {
    var _a;
    this._realTime = void 0;
    await ((_a = this._currentRealTimeTimer) == null ? void 0 : _a.dispose());
    this._currentRealTimeTimer = void 0;
  }
  resume() {
    this._replayLogOnce();
    this._innerResume();
  }
  _innerResume() {
    const now = this._embedder.performanceNow();
    this._realTime = { startTicks: now, lastSyncTicks: now };
    this._updateRealTimeTimer();
  }
  _updateRealTimeTimer() {
    var _a;
    if ((_a = this._currentRealTimeTimer) == null ? void 0 : _a.promise) {
      return;
    }
    const firstTimer = this._firstTimer();
    const nextTick = Math.min(firstTimer ? firstTimer.callAt : this._now.ticks + maxTimeout, this._now.ticks + 100);
    const callAt = this._currentRealTimeTimer ? Math.min(this._currentRealTimeTimer.callAt, nextTick) : nextTick;
    if (this._currentRealTimeTimer) {
      this._currentRealTimeTimer.cancel();
      this._currentRealTimeTimer = void 0;
    }
    const realTimeTimer = {
      callAt,
      promise: void 0,
      cancel: this._embedder.setTimeout(() => {
        this._syncRealTime();
        realTimeTimer.promise = this._runTo(this._now.ticks).catch((e) => console.error(e));
        void realTimeTimer.promise.then(() => {
          this._currentRealTimeTimer = void 0;
          if (this._realTime)
            this._updateRealTimeTimer();
        });
      }, callAt - this._now.ticks),
      dispose: async () => {
        realTimeTimer.cancel();
        await realTimeTimer.promise;
      }
    };
    this._currentRealTimeTimer = realTimeTimer;
  }
  async _runWithDisabledRealTimeSync(fn) {
    if (!this._realTime) {
      await fn();
      return;
    }
    await this._innerPause();
    try {
      await fn();
    } finally {
      this._innerResume();
    }
  }
  async fastForward(ticks) {
    this._replayLogOnce();
    await this._runWithDisabledRealTimeSync(async () => {
      await this._innerFastForwardTo(shiftTicks(this._now.ticks, ticks | 0));
    });
  }
  async _innerFastForwardTo(to) {
    if (to < this._now.ticks)
      throw new Error("Cannot fast-forward to the past");
    for (const timer of this._timers.values()) {
      if (to > timer.callAt)
        timer.callAt = to;
    }
    await this._runTo(to);
  }
  addTimer(options) {
    this._replayLogOnce();
    if (options.type === "AnimationFrame" /* AnimationFrame */ && !options.func)
      throw new Error("Callback must be provided to requestAnimationFrame calls");
    if (options.type === "IdleCallback" /* IdleCallback */ && !options.func)
      throw new Error("Callback must be provided to requestIdleCallback calls");
    if (["Timeout" /* Timeout */, "Interval" /* Interval */].includes(options.type) && !options.func && options.delay === void 0)
      throw new Error("Callback must be provided to timer calls");
    let delay = options.delay ? +options.delay : 0;
    if (!Number.isFinite(delay))
      delay = 0;
    delay = delay > maxTimeout ? 1 : delay;
    delay = Math.max(0, delay);
    const timer = {
      type: options.type,
      func: options.func,
      args: options.args || [],
      delay,
      callAt: shiftTicks(this._now.ticks, delay || (this._duringTick ? 1 : 0)),
      createdAt: this._now.ticks,
      id: this._uniqueTimerId++,
      error: new Error()
    };
    this._timers.set(timer.id, timer);
    if (this._realTime)
      this._updateRealTimeTimer();
    return timer.id;
  }
  countTimers() {
    return this._timers.size;
  }
  _firstTimer(beforeTick) {
    let firstTimer = null;
    for (const timer of this._timers.values()) {
      const isInRange = beforeTick === void 0 || timer.callAt <= beforeTick;
      if (isInRange && (!firstTimer || compareTimers(firstTimer, timer) === 1))
        firstTimer = timer;
    }
    return firstTimer;
  }
  _takeFirstTimer(beforeTick) {
    const timer = this._firstTimer(beforeTick);
    if (!timer)
      return null;
    this._advanceNow(timer.callAt);
    if (timer.type === "Interval" /* Interval */)
      timer.callAt = shiftTicks(timer.callAt, timer.delay);
    else
      this._timers.delete(timer.id);
    return timer;
  }
  async _callFirstTimer(beforeTick) {
    const timer = this._takeFirstTimer(beforeTick);
    if (!timer)
      return { timerFound: false };
    this._duringTick = true;
    try {
      if (typeof timer.func !== "function") {
        let error2;
        try {
          (() => {
            globalThis.eval(timer.func);
          })();
        } catch (e) {
          error2 = e;
        }
        await new Promise((f) => this._embedder.setTimeout(f));
        return { timerFound: true, error: error2 };
      }
      let args = timer.args;
      if (timer.type === "AnimationFrame" /* AnimationFrame */)
        args = [this._now.ticks];
      else if (timer.type === "IdleCallback" /* IdleCallback */)
        args = [{ didTimeout: false, timeRemaining: () => 0 }];
      let error;
      try {
        timer.func.apply(null, args);
      } catch (e) {
        error = e;
      }
      await new Promise((f) => this._embedder.setTimeout(f));
      return { timerFound: true, error };
    } finally {
      this._duringTick = false;
    }
  }
  getTimeToNextFrame() {
    this._replayLogOnce();
    return 16 - this._now.ticks % 16;
  }
  clearTimer(timerId, type) {
    this._replayLogOnce();
    if (!timerId) {
      return;
    }
    const id = Number(timerId);
    if (Number.isNaN(id) || id < idCounterStart) {
      const handlerName = getClearHandler(type);
      new Error(`Clock: ${handlerName} was invoked to clear a native timer instead of one created by the clock library.`);
    }
    const timer = this._timers.get(id);
    if (timer) {
      if (timer.type === type || timer.type === "Timeout" && type === "Interval" || timer.type === "Interval" && type === "Timeout") {
        this._timers.delete(id);
      } else {
        const clear = getClearHandler(type);
        const schedule = getScheduleHandler(timer.type);
        throw new Error(
          `Cannot clear timer: timer created with ${schedule}() but cleared with ${clear}()`
        );
      }
    }
  }
  _replayLogOnce() {
    if (!this._log.length)
      return;
    let lastLogTime = -1;
    let isPaused = false;
    for (const { type, time, param } of this._log) {
      if (!isPaused && lastLogTime !== -1)
        this._advanceNow(shiftTicks(this._now.ticks, time - lastLogTime));
      lastLogTime = time;
      if (type === "install") {
        this._innerInstall(asWallTime(param));
      } else if (type === "fastForward" || type === "runFor") {
        this._advanceNow(shiftTicks(this._now.ticks, param));
      } else if (type === "pauseAt") {
        isPaused = true;
        this._innerSetTime(asWallTime(param));
      } else if (type === "resume") {
        isPaused = false;
      } else if (type === "setFixedTime") {
        this._innerSetFixedTime(asWallTime(param));
      } else if (type === "setSystemTime") {
        this._innerSetTime(asWallTime(param));
      }
    }
    if (!isPaused) {
      if (lastLogTime > 0)
        this._advanceNow(shiftTicks(this._now.ticks, this._embedder.dateNow() - lastLogTime));
      this._innerResume();
    } else {
      this._realTime = void 0;
    }
    this._log.length = 0;
  }
};
function mirrorDateProperties(target, source) {
  for (const prop in source) {
    if (source.hasOwnProperty(prop))
      target[prop] = source[prop];
  }
  target.toString = () => source.toString();
  target.prototype = source.prototype;
  target.parse = source.parse;
  target.UTC = source.UTC;
  target.prototype.toUTCString = source.prototype.toUTCString;
  target.isFake = true;
  return target;
}
function createDate(clock, NativeDate) {
  function ClockDate(year, month, date, hour, minute, second, ms) {
    if (!(this instanceof ClockDate))
      return new NativeDate(clock.now()).toString();
    switch (arguments.length) {
      case 0:
        return new NativeDate(clock.now());
      case 1:
        return new NativeDate(year);
      case 2:
        return new NativeDate(year, month);
      case 3:
        return new NativeDate(year, month, date);
      case 4:
        return new NativeDate(year, month, date, hour);
      case 5:
        return new NativeDate(year, month, date, hour, minute);
      case 6:
        return new NativeDate(
          year,
          month,
          date,
          hour,
          minute,
          second
        );
      default:
        return new NativeDate(
          year,
          month,
          date,
          hour,
          minute,
          second,
          ms
        );
    }
  }
  ClockDate.now = () => clock.now();
  return mirrorDateProperties(ClockDate, NativeDate);
}
function createIntl(clock, NativeIntl) {
  const ClockIntl = {};
  for (const key of Object.getOwnPropertyNames(NativeIntl))
    ClockIntl[key] = NativeIntl[key];
  ClockIntl.DateTimeFormat = function(...args) {
    const realFormatter = new NativeIntl.DateTimeFormat(...args);
    const formatter = {
      formatRange: realFormatter.formatRange.bind(realFormatter),
      formatRangeToParts: realFormatter.formatRangeToParts.bind(realFormatter),
      resolvedOptions: realFormatter.resolvedOptions.bind(realFormatter),
      format: (date) => realFormatter.format(date || clock.now()),
      formatToParts: (date) => realFormatter.formatToParts(date || clock.now())
    };
    return formatter;
  };
  ClockIntl.DateTimeFormat.prototype = Object.create(
    NativeIntl.DateTimeFormat.prototype
  );
  ClockIntl.DateTimeFormat.supportedLocalesOf = NativeIntl.DateTimeFormat.supportedLocalesOf;
  return ClockIntl;
}
function compareTimers(a, b) {
  if (a.callAt < b.callAt)
    return -1;
  if (a.callAt > b.callAt)
    return 1;
  if (a.type === "Immediate" /* Immediate */ && b.type !== "Immediate" /* Immediate */)
    return -1;
  if (a.type !== "Immediate" /* Immediate */ && b.type === "Immediate" /* Immediate */)
    return 1;
  if (a.createdAt < b.createdAt)
    return -1;
  if (a.createdAt > b.createdAt)
    return 1;
  if (a.id < b.id)
    return -1;
  if (a.id > b.id)
    return 1;
}
var maxTimeout = Math.pow(2, 31) - 1;
var idCounterStart = 1e12;
function platformOriginals(globalObject) {
  const raw = {
    setTimeout: globalObject.setTimeout,
    clearTimeout: globalObject.clearTimeout,
    setInterval: globalObject.setInterval,
    clearInterval: globalObject.clearInterval,
    requestAnimationFrame: globalObject.requestAnimationFrame ? globalObject.requestAnimationFrame : void 0,
    cancelAnimationFrame: globalObject.cancelAnimationFrame ? globalObject.cancelAnimationFrame : void 0,
    requestIdleCallback: globalObject.requestIdleCallback ? globalObject.requestIdleCallback : void 0,
    cancelIdleCallback: globalObject.cancelIdleCallback ? globalObject.cancelIdleCallback : void 0,
    Date: globalObject.Date,
    performance: globalObject.performance,
    Intl: globalObject.Intl,
    AbortSignal: globalObject.AbortSignal
  };
  const bound = { ...raw };
  for (const key of Object.keys(bound)) {
    if (key !== "Date" && key !== "AbortSignal" && typeof bound[key] === "function")
      bound[key] = bound[key].bind(globalObject);
  }
  return { raw, bound };
}
function getScheduleHandler(type) {
  if (type === "IdleCallback" || type === "AnimationFrame")
    return `request${type}`;
  return `set${type}`;
}
function createApi(clock, originals, browserName) {
  return {
    setTimeout: (func, timeout, ...args) => {
      const delay = timeout ? +timeout : timeout;
      return clock.addTimer({
        type: "Timeout" /* Timeout */,
        func,
        args,
        delay
      });
    },
    clearTimeout: (timerId) => {
      if (timerId)
        clock.clearTimer(timerId, "Timeout" /* Timeout */);
    },
    setInterval: (func, timeout, ...args) => {
      const delay = timeout ? +timeout : timeout;
      return clock.addTimer({
        type: "Interval" /* Interval */,
        func,
        args,
        delay
      });
    },
    clearInterval: (timerId) => {
      if (timerId)
        return clock.clearTimer(timerId, "Interval" /* Interval */);
    },
    requestAnimationFrame: (callback) => {
      return clock.addTimer({
        type: "AnimationFrame" /* AnimationFrame */,
        func: callback,
        delay: clock.getTimeToNextFrame()
      });
    },
    cancelAnimationFrame: (timerId) => {
      if (timerId)
        return clock.clearTimer(timerId, "AnimationFrame" /* AnimationFrame */);
    },
    requestIdleCallback: (callback, options) => {
      let timeToNextIdlePeriod = 0;
      if (clock.countTimers() > 0)
        timeToNextIdlePeriod = 50;
      return clock.addTimer({
        type: "IdleCallback" /* IdleCallback */,
        func: callback,
        delay: (options == null ? void 0 : options.timeout) ? Math.min(options == null ? void 0 : options.timeout, timeToNextIdlePeriod) : timeToNextIdlePeriod
      });
    },
    cancelIdleCallback: (timerId) => {
      if (timerId)
        return clock.clearTimer(timerId, "IdleCallback" /* IdleCallback */);
    },
    Intl: originals.Intl ? createIntl(clock, originals.Intl) : void 0,
    Date: createDate(clock, originals.Date),
    performance: originals.performance ? fakePerformance(clock, originals.performance) : void 0,
    AbortSignal: originals.AbortSignal ? fakeAbortSignal(clock, originals.AbortSignal, browserName) : void 0
  };
}
function getClearHandler(type) {
  if (type === "IdleCallback" || type === "AnimationFrame")
    return `cancel${type}`;
  return `clear${type}`;
}
var FakePerformanceEntry = class {
  constructor(name, entryType, startTime, duration) {
    this.name = name;
    this.entryType = entryType;
    this.startTime = startTime;
    this.duration = duration;
  }
  toJSON() {
    return JSON.stringify({ ...this });
  }
};
function fakePerformance(clock, performance) {
  const result = {
    now: () => clock.performanceNow()
  };
  result.__defineGetter__("timeOrigin", () => clock._now.origin || 0);
  for (const key of Object.keys(performance.__proto__)) {
    if (key === "now" || key === "timeOrigin")
      continue;
    if (key === "getEntries" || key === "getEntriesByName" || key === "getEntriesByType")
      result[key] = () => [];
    else if (key === "mark")
      result[key] = (name) => new FakePerformanceEntry(name, "mark", 0, 0);
    else if (key === "measure")
      result[key] = (name) => new FakePerformanceEntry(name, "measure", 0, 50);
    else
      result[key] = () => {
      };
  }
  return result;
}
function fakeAbortSignal(clock, abortSignal, browserName) {
  Object.defineProperty(abortSignal, "timeout", {
    value(ms) {
      const controller = new AbortController();
      clock.addTimer({
        delay: ms,
        type: "Timeout" /* Timeout */,
        func: () => controller.abort(
          new DOMException(
            browserName === "chromium" ? "signal timed out" : "The operation timed out.",
            "TimeoutError"
          )
        )
      });
      return controller.signal;
    }
  });
  return abortSignal;
}
function createClock(globalObject, config = {}) {
  const originals = platformOriginals(globalObject);
  const embedder = {
    dateNow: () => originals.raw.Date.now(),
    performanceNow: () => Math.ceil(originals.raw.performance.now()),
    setTimeout: (task, timeout) => {
      const timerId = originals.bound.setTimeout(task, timeout);
      return () => originals.bound.clearTimeout(timerId);
    },
    setInterval: (task, delay) => {
      const intervalId = originals.bound.setInterval(task, delay);
      return () => originals.bound.clearInterval(intervalId);
    }
  };
  const clock = new ClockController(embedder);
  const api = createApi(clock, originals.bound, config.browserName);
  return { clock, api, originals: originals.raw };
}
function install(globalObject, config = {}) {
  var _a, _b;
  if ((_a = globalObject.Date) == null ? void 0 : _a.isFake) {
    throw new TypeError(`Can't install fake timers twice on the same global object.`);
  }
  const { clock, api, originals } = createClock(globalObject, config);
  const toFake = ((_b = config.toFake) == null ? void 0 : _b.length) ? config.toFake : Object.keys(originals);
  for (const method of toFake) {
    if (method === "Date") {
      globalObject.Date = mirrorDateProperties(api.Date, globalObject.Date);
    } else if (method === "Intl") {
      globalObject.Intl = api[method];
    } else if (method === "AbortSignal") {
      globalObject.AbortSignal = api[method];
    } else if (method === "performance") {
      globalObject.performance = api[method];
      const kEventTimeStamp = /* @__PURE__ */ Symbol("playwrightEventTimeStamp");
      Object.defineProperty(Event.prototype, "timeStamp", {
        get() {
          var _a2;
          if (!this[kEventTimeStamp])
            this[kEventTimeStamp] = (_a2 = api.performance) == null ? void 0 : _a2.now();
          return this[kEventTimeStamp];
        }
      });
    } else {
      globalObject[method] = (...args) => {
        return api[method].apply(api, args);
      };
    }
    clock.disposables.push(() => {
      globalObject[method] = originals[method];
    });
  }
  return { clock, api, originals };
}
function inject(globalObject, browserName) {
  const builtins = platformOriginals(globalObject).bound;
  const { clock: controller } = install(globalObject, { browserName });
  controller.resume();
  return {
    controller,
    builtins
  };
}
function asWallTime(n) {
  return n;
}
function shiftTicks(ticks, ms) {
  return ticks + ms;
}
