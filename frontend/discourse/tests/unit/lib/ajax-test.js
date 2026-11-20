import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { ajax } from "discourse/lib/ajax";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

const INTERNAL_SERVER_ERROR = 500;

module("Unit | Lib | ajax", function (hooks) {
  setupTest(hooks);

  test("rejects when the CSRF token request fails", async function (assert) {
    pretender.get("/session/csrf", () => response(INTERNAL_SERVER_ERROR, {}));

    const error = await ajax("/posts", { type: "POST" }).then(
      () => "resolved",
      (rejection) => rejection
    );

    assert.strictEqual(
      error.jqXHR.status,
      INTERNAL_SERVER_ERROR,
      "the promise settles with the CSRF failure"
    );
  });

  test("aborting before the CSRF token resolves does not throw", async function (assert) {
    assert.expect(0);
    pretender.get("/session/csrf", () => response({ csrf: "csrf-token" }));
    pretender.post("/posts", () => response({}));

    const promise = ajax("/posts", { type: "POST" });

    promise.abort();

    await promise;
  });
});
