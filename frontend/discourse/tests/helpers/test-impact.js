const BINDING = "__testImpactTake";
const BINDING_WAIT_MS = 10000;

// While the test impact map is recorded (see patch-testem-test-impact.js),
// waits at the start of each top-level module for the coverage of the one
// before to be taken, handing over where the module's first test is defined.
export async function setupTestImpact(QUnit) {
  if (!new URLSearchParams(window.location.search).has("test_impact")) {
    return;
  }

  const started = Date.now();
  while (typeof window[BINDING] !== "function") {
    if (Date.now() - started > BINDING_WAIT_MS) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 50));
  }

  // Shuffled tests interleave modules, and async work a test leaves behind
  // would land in another module's coverage. bin/qunit leaves out the seed
  // for tests registered at boot; this covers those loaded from here on.
  QUnit.config.seed = undefined;

  let current;
  QUnit.testStart(() => {
    const test = QUnit.config.current;
    let module = test.module;
    while (module.parentModule) {
      module = module.parentModule;
    }
    if (module === current) {
      return;
    }

    current = module;
    return new Promise((resolve) => {
      window.__testImpactTaken = resolve;
      window[BINDING](
        JSON.stringify({ module: module.name, stack: test.stack })
      );
    });
  });
}
