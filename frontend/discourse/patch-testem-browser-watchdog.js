const BrowserTestRunner = require("testem/lib/runners/browser_test_runner");

const patchedRunnerClasses = new WeakSet();

// Patches testem's browser runner so a browser that connects but then stops making
// test progress (for example a stalled or wedged headless Chrome) fails the run
// instead of hanging indefinitely. The failure is fast and reports a clear reason, so
// when the run was launched in an automated way (for example by an agent or in CI) the
// caller can react and retry the whole run rather than blocking on a wedged browser.
function installBrowserWatchdog(
  RunnerClass,
  {
    inactivityTimeout,
    setTimeout: setTimer = setTimeout,
    clearTimeout: clearTimer = clearTimeout,
  }
) {
  if (patchedRunnerClasses.has(RunnerClass)) {
    return;
  }
  patchedRunnerClasses.add(RunnerClass);

  function clearWatchdog(runner) {
    if (runner.browserWatchdogTimer) {
      clearTimer(runner.browserWatchdogTimer);
      runner.browserWatchdogTimer = undefined;
    }
  }

  function scheduleWatchdog(runner) {
    clearWatchdog(runner);
    runner.browserWatchdogTimer = setTimer(() => {
      runner.browserWatchdogTimer = undefined;
      if (runner.finished) {
        return;
      }

      const message =
        `Browser made no test progress for ${inactivityTimeout} seconds outside ` +
        `an active test; failing fast so the run can be retried.`;

      // Surface the reason on stderr as well as through the test result, so it is
      // visible in the console output even when the reporter summary is truncated.
      // eslint-disable-next-line no-console
      console.error(`\n[browser-watchdog] ${message}`);

      runner.reportResults(new Error(message), 0);
    }, inactivityTimeout * 1000);
  }

  const originalTryAttach = RunnerClass.prototype.tryAttach;
  RunnerClass.prototype.tryAttach = function (browser, id, socket) {
    const result = originalTryAttach.call(this, browser, id, socket);
    if (result === false) {
      return result;
    }

    scheduleWatchdog(this);
    socket.on("tests-start", () => clearWatchdog(this));
    socket.on("test-result", () => scheduleWatchdog(this));
    socket.on("all-test-results", () => clearWatchdog(this));
    socket.on("after-tests-complete", () => clearWatchdog(this));
    socket.on("disconnect", () => clearWatchdog(this));

    return result;
  };

  const originalFinish = RunnerClass.prototype.finish;
  RunnerClass.prototype.finish = function (...args) {
    clearWatchdog(this);
    return originalFinish.apply(this, args);
  };
}

function patchTestemBrowserWatchdog() {
  if (process.env.QUNIT_BROWSER_WATCHDOG !== "1") {
    return;
  }

  installBrowserWatchdog(BrowserTestRunner, {
    inactivityTimeout: parseInt(
      process.env.QUNIT_BROWSER_INACTIVITY_TIMEOUT,
      10
    ),
  });
}

module.exports = patchTestemBrowserWatchdog;
