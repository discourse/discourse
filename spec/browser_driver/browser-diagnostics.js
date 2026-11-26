(() => {
  if (globalThis.__discourseSystemLogs) {
    return;
  }
  const logs = (globalThis.__discourseSystemLogs = []);
  const append = (type, message, stack) => {
    logs.push({ type, message, stack });
  };
  const format = (value) => {
    if (typeof value === "string" || value instanceof Error) {
      return String(value);
    }
    try {
      return JSON.stringify(value) ?? String(value);
    } catch {
      return String(value);
    }
  };
  for (const type of ["debug", "log", "info", "warn", "error"]) {
    const original = console[type];
    console[type] = (...args) => {
      append(type, args.map(format).join(" "));
      return original.apply(console, args);
    };
  }
  addEventListener("error", (event) => {
    if (event instanceof ErrorEvent) {
      append("pageerror", event.message, event.error?.stack);
    }
  });
  addEventListener("unhandledrejection", (event) => {
    append("pageerror", format(event.reason), event.reason?.stack);
  });
})();
