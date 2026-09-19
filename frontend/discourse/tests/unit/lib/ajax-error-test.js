import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { ajax } from "discourse/lib/ajax";
import {
  extractError,
  isRateLimitError,
  rateLimitWaitSeconds,
} from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import pretender, {
  middlewareRateLimit,
  TOO_MANY_REQUESTS,
} from "discourse/tests/helpers/create-pretender";
import { i18n } from "discourse-i18n";

const INTERNAL_SERVER_ERROR = 500;
const RETRY_AFTER_SECONDS = 12;
const WAIT_SECONDS = 300;
const DEFAULT_WAIT_SECONDS = 15;

const SERVER_MESSAGE =
  "You’ve performed this action too many times. Please wait 5 minutes before trying again.";

function controllerRateLimit() {
  return [
    TOO_MANY_REQUESTS,
    { "Content-Type": "application/json", "Retry-After": String(WAIT_SECONDS) },
    {
      errors: [SERVER_MESSAGE],
      error_type: "rate_limit",
      extras: { wait_seconds: WAIT_SECONDS, time_left: "5 minutes" },
    },
  ];
}

function ajaxError(url) {
  return ajax(url).then(
    () => null,
    (error) => error
  );
}

function rawXHR(url) {
  return new Promise((resolve) => {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", getURL(url));
    xhr.onloadend = () => resolve(xhr);
    xhr.send();
  });
}

module("Unit | Lib | ajax-error", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/middleware-limit", () =>
      middlewareRateLimit(RETRY_AFTER_SECONDS)
    );
    pretender.get("/controller-limit", controllerRateLimit);
  });

  test("isRateLimitError detects both response shapes", async function (assert) {
    pretender.get("/server-error", () => [
      INTERNAL_SERVER_ERROR,
      { "Content-Type": "application/json" },
      { errors: ["boom"] },
    ]);

    assert.true(
      isRateLimitError(await ajaxError("/middleware-limit")),
      "detects the middleware rate limit from a jqXHR"
    );
    assert.true(
      isRateLimitError(await rawXHR("/middleware-limit")),
      "detects the middleware rate limit from a raw XHR"
    );
    assert.true(
      isRateLimitError({ source: await rawXHR("/middleware-limit") }),
      "detects the middleware rate limit from an XHR wrapped in source"
    );
    assert.true(
      isRateLimitError(await ajaxError("/controller-limit")),
      "detects the controller rate limit"
    );
    assert.false(
      isRateLimitError(await ajaxError("/server-error")),
      "ignores other errors"
    );
  });

  test("rateLimitWaitSeconds reads the Retry-After header", async function (assert) {
    assert.strictEqual(
      rateLimitWaitSeconds(await ajaxError("/middleware-limit")),
      RETRY_AFTER_SECONDS,
      "reads the header from a jqXHR"
    );
    assert.strictEqual(
      rateLimitWaitSeconds(await rawXHR("/middleware-limit")),
      RETRY_AFTER_SECONDS,
      "reads the header from a raw XHR"
    );
    assert.strictEqual(
      rateLimitWaitSeconds({ source: await rawXHR("/middleware-limit") }),
      RETRY_AFTER_SECONDS,
      "reads the header from an XHR wrapped in source"
    );
  });

  test("rateLimitWaitSeconds falls back to extras.wait_seconds", async function (assert) {
    pretender.get("/controller-limit", () => [
      TOO_MANY_REQUESTS,
      { "Content-Type": "application/json" },
      { errors: [SERVER_MESSAGE], extras: { wait_seconds: WAIT_SECONDS } },
    ]);

    assert.strictEqual(
      rateLimitWaitSeconds(await ajaxError("/controller-limit")),
      WAIT_SECONDS,
      "uses the wait time advertised in the body"
    );
  });

  test("rateLimitWaitSeconds defaults when no wait time is advertised", async function (assert) {
    pretender.get("/bare-limit", () => middlewareRateLimit(null));

    assert.strictEqual(
      rateLimitWaitSeconds(await ajaxError("/bare-limit")),
      DEFAULT_WAIT_SECONDS,
      "falls back to the default wait time"
    );
  });

  test("extractError translates a plain text rate limit", async function (assert) {
    const error = await ajaxError("/middleware-limit");
    const consoleError = sinon.stub(console, "error");

    const message = extractError(error);

    assert.strictEqual(
      message,
      i18n("too_many_requests", { count: RETRY_AFTER_SECONDS }),
      "returns a translated message mentioning the wait time"
    );
    assert.false(
      consoleError.called,
      "does not report a JSON parse failure for a plain text body"
    );
  });

  test("extractError keeps the server message for a JSON rate limit", async function (assert) {
    assert.strictEqual(
      extractError(await ajaxError("/controller-limit")),
      i18n("generic_error_with_reason", { error: SERVER_MESSAGE }),
      "prefers the localized message from the server"
    );
  });
});
