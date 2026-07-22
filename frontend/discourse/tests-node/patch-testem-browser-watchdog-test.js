const assert = require("node:assert/strict");
const { EventEmitter } = require("node:events");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { test } = require("node:test");

const {
  installBrowserWatchdog,
  markBrowserStartFailure,
  markBrowserTestFailure,
} = require("../patch-testem-browser-watchdog");

function setupWatchdog() {
  let pendingTimer;
  let clearedTimers = 0;

  class BrowserTestRunner {
    finish() {
      this.finished = true;
    }

    reportResults(error) {
      this.reportedError = error;
      this.finish();
    }

    tryAttach() {
      return true;
    }
  }

  installBrowserWatchdog(BrowserTestRunner, {
    inactivityTimeout: 30,
    setTimeout(callback) {
      pendingTimer = () => {
        pendingTimer = undefined;
        callback();
      };
      return pendingTimer;
    },
    clearTimeout(timer) {
      if (timer) {
        clearedTimers += 1;
      }
      if (pendingTimer === timer) {
        pendingTimer = undefined;
      }
    },
  });

  const runner = new BrowserTestRunner();
  const socket = new EventEmitter();
  runner.tryAttach("TestBrowser", 1, socket);

  return {
    get clearedTimers() {
      return clearedTimers;
    },
    get pendingTimer() {
      return pendingTimer;
    },
    runner,
    socket,
  };
}

test("reports a browser that connects but does not start a test", () => {
  const watchdog = setupWatchdog();

  watchdog.pendingTimer();

  assert.match(watchdog.runner.reportedError.message, /30 seconds/);
  assert.equal(watchdog.runner.finished, true);
  assert.equal(watchdog.pendingTimer, undefined);
});

test("suspends the timer during a test and restarts it after the result", () => {
  const watchdog = setupWatchdog();

  watchdog.socket.emit("tests-start");
  assert.equal(watchdog.pendingTimer, undefined);

  watchdog.socket.emit("test-result", {});
  assert.equal(typeof watchdog.pendingTimer, "function");
});

test("does not treat browser console output as test progress", () => {
  const watchdog = setupWatchdog();
  const initialTimer = watchdog.pendingTimer;

  watchdog.socket.emit("browser-console", "log", "still running");

  assert.equal(watchdog.pendingTimer, initialTimer);
  assert.equal(watchdog.clearedTimers, 0);
});

test("clears the timer when the runner finishes", () => {
  const watchdog = setupWatchdog();

  watchdog.runner.finish();

  assert.equal(watchdog.pendingTimer, undefined);
  assert.equal(watchdog.clearedTimers, 1);
});

test("marks only browser connection timeouts as retryable", () => {
  const markerPath = path.join(
    os.tmpdir(),
    `qunit-browser-start-failure-${process.pid}`
  );

  try {
    assert.equal(
      markBrowserStartFailure(
        {
          name: "error",
          error: { message: "Error: Browser failed to connect within 45s" },
        },
        markerPath
      ),
      true
    );
    assert.equal(fs.existsSync(markerPath), true);

    fs.rmSync(markerPath);
    assert.equal(
      markBrowserStartFailure(
        { name: "error", error: { message: "Expected true to equal false" } },
        markerPath
      ),
      false
    );
    assert.equal(fs.existsSync(markerPath), false);
  } finally {
    fs.rmSync(markerPath, { force: true });
  }
});

test("does not treat a test whose failure text mentions the timeout as a start failure", () => {
  const markerPath = path.join(
    os.tmpdir(),
    `qunit-browser-start-failure-name-${process.pid}`
  );

  try {
    // A real per-test result carries the test name, not "error", even if its assertion
    // message happens to contain the browser-start phrase.
    assert.equal(
      markBrowserStartFailure(
        {
          name: "asserts Browser failed to connect within 45s",
          failed: 1,
          error: { message: "Browser failed to connect within 45s" },
        },
        markerPath
      ),
      false
    );
    assert.equal(fs.existsSync(markerPath), false);
  } finally {
    fs.rmSync(markerPath, { force: true });
  }
});

test("marks a genuine test failure under the test-failure marker", () => {
  const markerPath = path.join(
    os.tmpdir(),
    `qunit-browser-test-failure-${process.pid}`
  );

  try {
    assert.equal(
      markBrowserTestFailure(
        {
          name: "renders the button",
          failed: 1,
          error: { message: "Expected true to equal false" },
        },
        markerPath
      ),
      true
    );
    assert.equal(fs.existsSync(markerPath), true);
  } finally {
    fs.rmSync(markerPath, { force: true });
  }
});

test("does not mark a browser-start failure as a test failure", () => {
  const markerPath = path.join(
    os.tmpdir(),
    `qunit-browser-test-failure-start-${process.pid}`
  );

  try {
    // The browser-start result is reported as a failure too, but it belongs to the
    // start-failure marker, not the test-failure marker.
    assert.equal(
      markBrowserTestFailure(
        {
          name: "error",
          failed: 1,
          error: { message: "Error: Browser failed to connect within 45s" },
        },
        markerPath
      ),
      false
    );
    assert.equal(fs.existsSync(markerPath), false);
  } finally {
    fs.rmSync(markerPath, { force: true });
  }
});

test("does not mark a passing result as a test failure", () => {
  const markerPath = path.join(
    os.tmpdir(),
    `qunit-browser-test-failure-pass-${process.pid}`
  );

  try {
    assert.equal(
      markBrowserTestFailure(
        { name: "renders the button", failed: 0 },
        markerPath
      ),
      false
    );
    assert.equal(fs.existsSync(markerPath), false);
  } finally {
    fs.rmSync(markerPath, { force: true });
  }
});
