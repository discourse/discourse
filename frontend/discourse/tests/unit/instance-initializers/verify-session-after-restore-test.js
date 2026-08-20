import { module, test } from "qunit";
import sinon from "sinon";
import { restoredSessionMatches } from "discourse/instance-initializers/verify-session-after-restore";

module(
  "Unit | Instance Initializer | verify-session-after-restore",
  function () {
    function stubSession(status, body = null) {
      sinon
        .stub(window, "fetch")
        .resolves(new Response(body && JSON.stringify(body), { status }));
    }

    test("matches when the same user is still logged in", async function (assert) {
      stubSession(200, { current_user: { id: 1 } });

      assert.true(await restoredSessionMatches(1), "same user id matches");
    });

    test("does not match when a different user is logged in", async function (assert) {
      stubSession(200, { current_user: { id: 2 } });

      assert.false(await restoredSessionMatches(1), "user id changed");
    });

    test("does not match when the session became anonymous", async function (assert) {
      stubSession(404);

      assert.false(
        await restoredSessionMatches(1),
        "document has a user but the session is anonymous"
      );
    });

    test("matches when both the document and the session are anonymous", async function (assert) {
      stubSession(404);

      assert.true(await restoredSessionMatches(null), "still anonymous");
    });

    test("does not match when the session gained a user", async function (assert) {
      stubSession(200, { current_user: { id: 1 } });

      assert.false(
        await restoredSessionMatches(null),
        "anonymous document but the session is logged in"
      );
    });

    test("matches on server errors", async function (assert) {
      stubSession(500);

      assert.true(
        await restoredSessionMatches(1),
        "server errors do not trigger a reload"
      );
    });

    test("matches on network failures", async function (assert) {
      sinon.stub(window, "fetch").rejects(new TypeError("network down"));

      assert.true(
        await restoredSessionMatches(1),
        "network failures do not trigger a reload"
      );
    });
  }
);
