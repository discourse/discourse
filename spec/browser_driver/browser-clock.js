(() => {
  if (globalThis.__discourseClock) {
    return;
  }

  const RealDate = Date;
  const realSetTimeout = setTimeout.bind(globalThis);
  const realClearTimeout = clearTimeout.bind(globalThis);
  const realSetInterval = setInterval.bind(globalThis);
  const timers = new Map();
  let offset = 0;
  let nextId = 0;
  const now = () => RealDate.now() + offset;

  function SystemDate(...args) {
    if (!new.target) {
      return new RealDate(now()).toString();
    }
    return Reflect.construct(RealDate, args.length ? args : [now()], new.target);
  }
  Object.setPrototypeOf(SystemDate, RealDate);
  SystemDate.prototype = RealDate.prototype;
  SystemDate.now = now;

  function clear(id) {
    const timer = timers.get(Number(id));
    if (timer) {
      realClearTimeout(timer.nativeId);
      timers.delete(timer.id);
    } else {
      realClearTimeout(id);
    }
  }

  function schedule(timer) {
    timer.nativeId = realSetTimeout(() => fire(timer), Math.max(0, timer.due - now()));
  }

  function fire(timer) {
    if (!timers.has(timer.id)) {
      return;
    }
    if (timer.repeats) {
      timer.due = now() + timer.delay;
      schedule(timer);
    } else {
      timers.delete(timer.id);
    }
    timer.callback.apply(globalThis, timer.args);
  }

  function create(callback, delay, args, repeats) {
    if (typeof callback !== "function") {
      const scheduleString = repeats ? realSetInterval : realSetTimeout;
      return scheduleString(callback, delay, ...args);
    }
    const wait = Math.max(0, Number(delay) || 0);
    const timer = { id: --nextId, callback, delay: wait, args, repeats, due: now() + wait };
    timers.set(timer.id, timer);
    schedule(timer);
    return timer.id;
  }

  globalThis.Date = SystemDate;
  globalThis.setTimeout = (callback, delay, ...args) => create(callback, delay, args, false);
  globalThis.setInterval = (callback, delay, ...args) => create(callback, delay, args, true);
  globalThis.clearTimeout = globalThis.clearInterval = clear;
  globalThis.__discourseClock = {
    setOffset(value) {
      offset = value;
    },
    fastForward(milliseconds) {
      offset += milliseconds;
      const elapsed = now();
      for (const timer of [...timers.values()].sort((first, second) => first.due - second.due)) {
        if (timer.due <= elapsed && timers.has(timer.id)) {
          realClearTimeout(timer.nativeId);
          try {
            fire(timer);
          } catch (error) {
            realSetTimeout(() => { throw error; });
          }
        }
      }
    },
  };
})();
