import { module, test } from "qunit";
import {
  __resetWaiters,
  registerSplashScreenWaiter,
  removeSplashScreen,
} from "discourse/lib/splash-screen";

module("Unit | Lib | splash-screen", function (hooks) {
  function deferred() {
    let resolve;
    let reject;

    const promise = new Promise((promiseResolve, promiseReject) => {
      resolve = promiseResolve;
      reject = promiseReject;
    });

    return { promise, resolve, reject };
  }

  hooks.beforeEach(function () {
    const splash = document.createElement("div");
    splash.id = "d-splash";
    document.body.appendChild(splash);
  });

  hooks.afterEach(function () {
    document.querySelector("#d-splash")?.remove();
    __resetWaiters();
  });

  test("removeSplashScreen removes #d-splash when there are no waiters", async function (assert) {
    const waiter = deferred();
    registerSplashScreenWaiter(() => waiter.promise);

    const removal = removeSplashScreen();

    assert.notStrictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should not be removed while waiters are pending"
    );

    waiter.resolve();
    await removal;

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed when there are no waiters"
    );
  });

  test("removeSplashScreen waits for every registered waiter", async function (assert) {
    const waiter1 = deferred();
    const waiter2 = deferred();

    registerSplashScreenWaiter(() => waiter1.promise);
    registerSplashScreenWaiter(() => waiter2.promise);

    const removal = removeSplashScreen();

    waiter1.resolve();
    await Promise.resolve();

    assert.notStrictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should not be removed until all waiters are resolved"
    );

    waiter2.resolve();
    await removal;

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed when all waiters are resolved"
    );
  });

  test("removeSplashScreen removes #d-splash even if some waiters reject", async function (assert) {
    const waiter1 = deferred();
    const waiter2 = deferred();

    registerSplashScreenWaiter(() => waiter1.promise);
    registerSplashScreenWaiter(() => waiter2.promise);

    const removal = removeSplashScreen();

    waiter1.reject(new Error("Something went wrong"));
    waiter2.resolve();
    await removal;

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed even if some waiters reject"
    );
  });
});
