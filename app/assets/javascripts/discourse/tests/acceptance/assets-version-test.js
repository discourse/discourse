import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import Sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import discoveryFixtures from "discourse/tests/fixtures/discovery-fixtures";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("Software update refresh", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.get("/hot.json", () => {
      return helper.response(cloneJSON(discoveryFixtures["/latest.json"]));
    });
  });

  test("Refreshes page on next navigation", async function (assert) {
    const redirectStub = Sinon.stub(DiscourseURL, "redirectTo");

    await visit("/");
    await click(".nav-item_hot a");
    assert.true(
      redirectStub.notCalled,
      "redirect was not triggered by default"
    );

    await publishToMessageBus("/global/asset-version", "somenewversion");

    redirectStub.resetHistory();
    await visit("/");
    await click(".nav-item_hot a");
    assert.true(
      redirectStub.calledWith("/hot"),
      "redirect was triggered after asset change"
    );

    redirectStub.resetHistory();
    await visit("/");
    await click("#create-topic");
    await click(".nav-item_hot a");
    assert.true(
      redirectStub.notCalled,
      "redirect is not triggered while composer is open"
    );

    redirectStub.resetHistory();
    await visit("/");
    await click(".save-or-cancel .cancel");
    await click(".nav-item_hot a");
    assert.true(
      redirectStub.calledWith("/hot"),
      "redirect is triggered on next navigation after composer closed"
    );
  });
});
