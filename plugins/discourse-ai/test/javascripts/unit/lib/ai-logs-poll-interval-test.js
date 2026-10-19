import { module, test } from "qunit";
import {
  NEW_LOGS_POLL_BACKOFF_STEP_MS,
  NEW_LOGS_POLL_INTERVAL_MS,
  NEW_LOGS_POLL_MAX_INTERVAL_MS,
  newLogsPollIntervalMs,
} from "discourse/plugins/discourse-ai/discourse/lib/ai-logs-poll-interval";

module("Unit | Lib | ai-logs-poll-interval", function () {
  test("starts at the base interval with no quiet polls", function (assert) {
    assert.strictEqual(newLogsPollIntervalMs(0), NEW_LOGS_POLL_INTERVAL_MS);
    assert.strictEqual(newLogsPollIntervalMs(-1), NEW_LOGS_POLL_INTERVAL_MS);
  });

  test("backs off one step per quiet poll", function (assert) {
    assert.strictEqual(
      newLogsPollIntervalMs(1),
      NEW_LOGS_POLL_INTERVAL_MS + NEW_LOGS_POLL_BACKOFF_STEP_MS
    );
    assert.strictEqual(
      newLogsPollIntervalMs(2),
      NEW_LOGS_POLL_INTERVAL_MS + 2 * NEW_LOGS_POLL_BACKOFF_STEP_MS
    );
  });

  test("caps the backoff at the maximum interval", function (assert) {
    const stepsToMax =
      (NEW_LOGS_POLL_MAX_INTERVAL_MS - NEW_LOGS_POLL_INTERVAL_MS) /
      NEW_LOGS_POLL_BACKOFF_STEP_MS;
    assert.strictEqual(
      newLogsPollIntervalMs(stepsToMax),
      NEW_LOGS_POLL_MAX_INTERVAL_MS
    );
    assert.strictEqual(
      newLogsPollIntervalMs(stepsToMax + 5),
      NEW_LOGS_POLL_MAX_INTERVAL_MS
    );
  });
});
