import { module, test } from "qunit";
import {
  __resetHolds,
  holdSplashScreen,
  removeSplashScreen,
} from "discourse/lib/splash-screen";

module("Unit | lib | splash-screen", function (hooks) {
  hooks.beforeEach(function () {
    const splash = document.createElement("div");
    splash.id = "d-splash";
    document.body.appendChild(splash);
  });

  hooks.afterEach(function () {
    document.querySelector("#d-splash")?.remove();
    __resetHolds();
  });

  test("removeSplashScreen removes #d-splash when there are no holds", function (assert) {
    removeSplashScreen();

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed when there are no holds"
    );
  });

  test("removeSplashScreen does not remove #d-splash when holds are active", function (assert) {
    const release = holdSplashScreen("test-hold");
    removeSplashScreen();

    assert.notStrictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should not be removed when holds are active"
    );

    release();
  });

  test("the splash is removed only after every hold is released", function (assert) {
    const release1 = holdSplashScreen("hold-1");
    const release2 = holdSplashScreen("hold-2");

    release1();

    assert.notStrictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should not be removed until all holds are released"
    );

    release2();

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed after all holds are released"
    );
  });

  test("release functions can only release their own hold once", function (assert) {
    const release1 = holdSplashScreen("hold-1");
    const release2 = holdSplashScreen("hold-2");

    release1();
    release1();

    assert.notStrictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should not be removed until all holds are released"
    );

    release2();

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed after all holds are released"
    );
  });

  test("holds with the same name are tracked separately", function (assert) {
    const release1 = holdSplashScreen("same-name");
    const release2 = holdSplashScreen("same-name");

    release1();

    assert.notStrictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should not be removed until all holds are released"
    );

    release2();

    assert.strictEqual(
      document.querySelector("#d-splash"),
      null,
      "The splash screen should be removed after all holds are released"
    );
  });
});
