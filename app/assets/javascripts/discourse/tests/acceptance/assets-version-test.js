import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import { click, visit } from "@ember/test-helpers";
import DiscourseURL from "discourse/lib/url";
import Sinon from "sinon";

acceptance("Software update refresh", function (needs) {
  needs.user();

  test("Refreshes page on next navigation", async function (assert) {
    const redirectStub = Sinon.stub(DiscourseURL, "redirectTo");

    await visit("/");
    await click(".nav-item_top a");
    assert.true(
      redirectStub.notCalled,
      "redirect was not triggered by default"
    );

    await publishToMessageBus("/global/asset-version", "somenewversion");

    redirectStub.resetHistory();
    await visit("/");
    await click(".nav-item_top a");
    assert.true(
      redirectStub.calledWith("/top"),
      "redirect was triggered after asset change"
    );

    redirectStub.resetHistory();
    await visit("/");
    await click("#create-topic");
    await click(".nav-item_top a");
    assert.true(
      redirectStub.notCalled,
      "redirect is not triggered while composer is open"
    );

    redirectStub.resetHistory();
    await visit("/");
    await click(".save-or-cancel .cancel");
    await click(".nav-item_top a");
    assert.true(
      redirectStub.calledWith("/top"),
      "redirect is triggered on next navigation after composer closed"
    );
  });
});
