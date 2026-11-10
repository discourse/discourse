const RUNNING_TEST_KEY = "discourse-qunit-running-test";

/**
 * Fails a test that leaves the test page. Otherwise the reload silently skips
 * the rest of its file, because a load-balanced browser moves on to the next one.
 *
 * Cancelable navigations are blocked and blamed on the code that started them.
 * Any other reload is reported by the first test after it, using the test name
 * kept in `storage`.
 *
 * @param {object} options
 * @param {object} options.qunit - the QUnit instance to report through.
 * @param {EventTarget} [options.navigation] - the Navigation API object, absent in some browsers.
 * @param {Storage} options.storage - storage that survives a reload of the page.
 */
export default function setupNavigationGuard({ qunit, navigation, storage }) {
  let pendingFailures = [];
  let lastFinishedTest;

  const interruptedTest = storage.getItem(RUNNING_TEST_KEY);
  if (interruptedTest) {
    storage.removeItem(RUNNING_TEST_KEY);
    pendingFailures.push({
      actual: interruptedTest,
      expected: "no page reload",
      message: `The page reloaded during "${interruptedTest}", so the rest of its file did not run.`,
    });
  }

  function onNavigate(event) {
    if (
      event.destination.sameDocument ||
      event.userInitiated ||
      event.downloadRequest != null ||
      !event.cancelable
    ) {
      return;
    }

    event.preventDefault();

    const url = event.destination.url;
    const when = qunit.config.current
      ? ""
      : ` after "${lastFinishedTest}" finished`;
    const failure = {
      actual: url,
      expected: "no cross-document navigation",
      message: `Blocked a navigation to ${url}${when}. It would have reloaded the test page and skipped the rest of its file.`,
      source: new Error().stack,
    };

    if (qunit.config.current) {
      qunit.config.current.pushResult({ result: false, ...failure });
    } else {
      pendingFailures.push(failure);
    }
  }

  qunit.begin(() => navigation?.addEventListener("navigate", onNavigate));
  qunit.done(() => navigation?.removeEventListener("navigate", onNavigate));

  qunit.testStart(({ module, name }) => {
    for (const failure of pendingFailures) {
      qunit.config.current.pushResult({ result: false, ...failure });
    }
    pendingFailures = [];

    storage.setItem(RUNNING_TEST_KEY, `${module} :: ${name}`);
  });

  qunit.testDone(({ module, name }) => {
    lastFinishedTest = `${module} :: ${name}`;
    storage.removeItem(RUNNING_TEST_KEY);
  });
}
