import sinon from "sinon";
import { clearCallbacks } from "discourse/select-kit/lib/plugin-api";
import DeprecationCounter from "discourse/tests/helpers/deprecation-counter";
import {
  disableRaiseOnDeprecation,
  enableRaiseOnDeprecation,
} from "discourse/tests/helpers/raise-on-deprecation";

/**
 * Sets up a module whose tests register `api.modifySelectKit` callbacks against `DSelect`.
 * The bridge deprecates every such use, so the deprecation must not raise, print or count, and
 * the registered callbacks are cleared after each test. The console stub is kept on the test
 * context as `bridgeWarn` for tests that assert on the deprecation.
 *
 * @param {NestedHooks} hooks
 */
export function setupLegacyBridgeCallbacks(hooks) {
  hooks.beforeEach(function () {
    disableRaiseOnDeprecation();
    this.bridgeWarn = sinon.stub(console, "warn");
    sinon.stub(DeprecationCounter.prototype, "incrementCount");
  });

  hooks.afterEach(function () {
    clearCallbacks();
    enableRaiseOnDeprecation();
  });
}
