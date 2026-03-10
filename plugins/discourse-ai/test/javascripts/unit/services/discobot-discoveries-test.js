import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | discobot-discoveries", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    const service = getOwner(this).lookup("service:discobot-discoveries");
    cancel(service.discoveryTimeout);
  });

  test("does not send duplicate requests for the same successful query", async function (assert) {
    let requestsCount = 0;

    pretender.post("/discourse-ai/discoveries/reply", () => {
      requestsCount += 1;
      return response(200, {});
    });

    const service = getOwner(this).lookup("service:discobot-discoveries");

    await service.triggerDiscovery("What is Discourse?");
    await service.triggerDiscovery("What is Discourse?");
    cancel(service.discoveryTimeout);

    assert.strictEqual(requestsCount, 1);
  });

  test("allows retrying the same query when the request fails", async function (assert) {
    let requestsCount = 0;

    pretender.post("/discourse-ai/discoveries/reply", () => {
      requestsCount += 1;
      return response(500, {});
    });

    const service = getOwner(this).lookup("service:discobot-discoveries");

    await service.triggerDiscovery("What is Discourse?");
    await service.triggerDiscovery("What is Discourse?");
    cancel(service.discoveryTimeout);

    assert.strictEqual(requestsCount, 2);
  });
});
