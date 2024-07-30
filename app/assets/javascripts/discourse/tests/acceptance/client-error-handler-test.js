import { getOwner } from "@ember/owner";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import Sinon from "sinon";
import { acceptance } from "../helpers/qunit-helpers";

acceptance("client-error-handler service", function (needs) {
  needs.user({
    admin: true,
  });

  test("displays route-loading errors caused by themes", async function (assert) {
    const fakeError = new Error("Something bad happened");
    fakeError.stack = "assets/plugins/some-fake-plugin-name.js";

    const topicRoute = getOwner(this).lookup("route:topic");
    Sinon.stub(topicRoute, "model").throws(fakeError);

    const consoleStub = Sinon.stub(console, "error");
    try {
      await visit("/t/280");
    } catch {}
    consoleStub.restore();

    assert.dom(".broken-theme-alert-banner").exists();
    assert
      .dom(".broken-theme-alert-banner")
      .containsText("some-fake-plugin-name");
  });
});
