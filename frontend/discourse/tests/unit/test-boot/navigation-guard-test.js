import { module, test } from "qunit";
import setupNavigationGuard from "discourse/tests/navigation-guard";

/**
 * Stands in for the QUnit callbacks the guard registers, and records the
 * results it pushes into each test.
 */
function fakeQUnit() {
  const callbacks = { begin: [], done: [], testStart: [], testDone: [] };
  const qunit = { config: { current: null }, results: [] };

  for (const name of Object.keys(callbacks)) {
    qunit[name] = (callback) => callbacks[name].push(callback);
  }

  qunit.trigger = (name, details = {}) =>
    callbacks[name].forEach((callback) => callback(details));

  qunit.startTest = (moduleName, testName) => {
    const results = [];
    qunit.results.push({ name: `${moduleName} :: ${testName}`, results });
    qunit.config.current = { pushResult: (result) => results.push(result) };
    qunit.trigger("testStart", { module: moduleName, name: testName });
  };

  qunit.finishTest = (moduleName, testName) => {
    qunit.trigger("testDone", { module: moduleName, name: testName });
    qunit.config.current = null;
  };

  return qunit;
}

function fakeStorage(entries = {}) {
  const map = new Map(Object.entries(entries));
  return {
    map,
    getItem: (key) => (map.has(key) ? map.get(key) : null),
    setItem: (key, value) => map.set(key, String(value)),
    removeItem: (key) => map.delete(key),
  };
}

function navigateEvent({
  url = "http://localhost:4200/elsewhere",
  sameDocument = false,
  userInitiated = false,
  downloadRequest = null,
  cancelable = true,
} = {}) {
  const event = new Event("navigate", { cancelable });
  Object.assign(event, {
    destination: { url, sameDocument },
    userInitiated,
    downloadRequest,
  });
  return event;
}

/**
 * Dispatches from a named function, so the test can find it in the reported
 * stack the way it would find the code that called `location.reload()`.
 */
function reloadFromCulprit(navigation, event) {
  navigation.dispatchEvent(event);
}

module("Unit | Test boot | navigation guard", function (hooks) {
  hooks.beforeEach(function () {
    this.qunit = fakeQUnit();
    this.navigation = new EventTarget();
    this.storage = fakeStorage();
    this.setup = () =>
      setupNavigationGuard({
        qunit: this.qunit,
        navigation: this.navigation,
        storage: this.storage,
      });
  });

  test("blocks a cross-document navigation and fails the running test with the caller's stack", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "some test");

    const event = navigateEvent({ url: "http://localhost:4200/c/bug/edit" });
    reloadFromCulprit(this.navigation, event);

    assert.true(event.defaultPrevented, "the navigation is cancelled");

    const [result, ...others] = this.qunit.results[0].results;
    assert.strictEqual(others.length, 0, "exactly one result is pushed");
    assert.false(result.result, "the result is a failure");
    assert.strictEqual(
      result.actual,
      "http://localhost:4200/c/bug/edit",
      "the failure names the destination"
    );
    assert.true(
      result.message.includes("http://localhost:4200/c/bug/edit"),
      "the message names the destination"
    );
    assert.true(
      result.source.includes("reloadFromCulprit"),
      "the source is the stack of the code that navigated"
    );
  });

  test("ignores same-document navigations", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "some test");

    const event = navigateEvent({ sameDocument: true });
    this.navigation.dispatchEvent(event);

    assert.false(event.defaultPrevented, "the navigation proceeds");
    assert.deepEqual(this.qunit.results[0].results, [], "nothing is reported");
  });

  test("ignores user-initiated navigations", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "some test");

    const event = navigateEvent({ userInitiated: true });
    this.navigation.dispatchEvent(event);

    assert.false(event.defaultPrevented, "the navigation proceeds");
    assert.deepEqual(this.qunit.results[0].results, [], "nothing is reported");
  });

  test("ignores downloads", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "some test");

    const event = navigateEvent({ downloadRequest: "report.csv" });
    this.navigation.dispatchEvent(event);

    assert.false(event.defaultPrevented, "the download proceeds");
    assert.deepEqual(this.qunit.results[0].results, [], "nothing is reported");
  });

  test("leaves navigations that cannot be cancelled to the interrupted-test report", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "some test");

    this.navigation.dispatchEvent(navigateEvent({ cancelable: false }));

    assert.deepEqual(this.qunit.results[0].results, [], "nothing is reported");
  });

  test("only guards between the start and the end of the run", function (assert) {
    this.setup();

    const before = navigateEvent();
    this.navigation.dispatchEvent(before);
    assert.false(before.defaultPrevented, "navigation before the run proceeds");

    this.qunit.trigger("begin");
    this.qunit.trigger("done");

    const after = navigateEvent();
    this.navigation.dispatchEvent(after);
    assert.false(after.defaultPrevented, "navigation after the run proceeds");
  });

  test("a navigation between tests fails the next test and names the previous one", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "first test");
    this.qunit.finishTest("Some module", "first test");

    const event = navigateEvent();
    reloadFromCulprit(this.navigation, event);
    assert.true(event.defaultPrevented, "the navigation is cancelled");

    this.qunit.startTest("Other module", "second test");

    const [first, second] = this.qunit.results;
    assert.deepEqual(first.results, [], "the finished test is not touched");

    const [result, ...others] = second.results;
    assert.strictEqual(others.length, 0, "exactly one result is pushed");
    assert.false(result.result, "the next test fails");
    assert.true(
      result.message.includes("Some module :: first test"),
      "the message names the test that had finished"
    );
    assert.true(
      result.source.includes("reloadFromCulprit"),
      "the source is the stack of the code that navigated"
    );
  });

  test("records the running test and forgets it when the test finishes", function (assert) {
    this.setup();
    this.qunit.trigger("begin");

    this.qunit.startTest("Some module", "some test");
    assert.deepEqual(
      [...this.storage.map.values()],
      ["Some module :: some test"],
      "the running test is stored"
    );

    this.qunit.finishTest("Some module", "some test");
    assert.strictEqual(this.storage.map.size, 0, "the entry is removed");
  });

  test("a test the page unloaded during fails the first test after the reload", function (assert) {
    this.setup();
    this.qunit.trigger("begin");
    this.qunit.startTest("Some module", "interrupted test");
    const stored = Object.fromEntries(this.storage.map);

    // Simulates the reload: a fresh page boots with the same session storage
    const qunit = fakeQUnit();
    const storage = fakeStorage(stored);
    setupNavigationGuard({ qunit, navigation: new EventTarget(), storage });
    qunit.trigger("begin");
    qunit.startTest("Other module", "next test");

    const [result, ...others] = qunit.results[0].results;
    assert.strictEqual(others.length, 0, "exactly one result is pushed");
    assert.false(result.result, "the next test fails");
    assert.true(
      result.message.includes("Some module :: interrupted test"),
      "the message names the interrupted test"
    );

    qunit.finishTest("Other module", "next test");
    qunit.startTest("Other module", "later test");
    assert.deepEqual(
      qunit.results[1].results,
      [],
      "the interruption is reported once"
    );
  });
});
