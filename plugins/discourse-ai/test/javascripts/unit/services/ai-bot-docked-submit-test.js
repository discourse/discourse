import { getOwner } from "@ember/owner";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Unit | Service | ai-bot-docked-submit", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    const siteSettings = getOwner(this).lookup("service:site-settings");
    siteSettings.min_personal_message_post_length = 10;
  });

  test("returns null when topicId is missing", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    const result = await service.submitReply({
      topicId: null,
      raw: "Hello world, this is long enough",
    });
    assert.strictEqual(result, null);
  });

  test("returns null when raw is missing", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    const result = await service.submitReply({ topicId: 42, raw: "" });
    assert.strictEqual(result, null);
  });

  test("returns null and alerts when raw is shorter than min length", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    let requestsCount = 0;
    pretender.post("/posts.json", () => {
      requestsCount += 1;
      return response(200, {});
    });

    const result = await service.submitReply({
      topicId: 42,
      raw: "hi",
      uploads: [],
      inProgressUploadsCount: 0,
    });

    assert.strictEqual(result, null);
    assert.strictEqual(requestsCount, 0, "no POST when too short");
  });

  test("returns null when uploads are still in progress", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    let requestsCount = 0;
    pretender.post("/posts.json", () => {
      requestsCount += 1;
      return response(200, {});
    });

    const result = await service.submitReply({
      topicId: 42,
      raw: "Long enough message here",
      uploads: [],
      inProgressUploadsCount: 2,
    });

    assert.strictEqual(result, null);
    assert.strictEqual(requestsCount, 0);
  });

  test("POSTs raw + topic_id + nested_post flag", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    let submittedBody;
    pretender.post("/posts.json", (request) => {
      submittedBody = request.requestBody;
      return response(200, { id: 999, topic_id: 42 });
    });

    const result = await service.submitReply({
      topicId: 42,
      raw: "Long enough message body",
      uploads: [],
      inProgressUploadsCount: 0,
    });

    assert.strictEqual(result.id, 999);
    assert.true(submittedBody.includes("topic_id=42"));
    assert.true(submittedBody.includes("nested_post=true"));
  });

  test("appends upload markdown to raw content", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    const formDataFromBody = (body) => {
      const params = new URLSearchParams(body);
      return params.get("raw");
    };
    let rawSent;
    pretender.post("/posts.json", (request) => {
      rawSent = formDataFromBody(request.requestBody);
      return response(200, { id: 1, topic_id: 42 });
    });

    await service.submitReply({
      topicId: 42,
      raw: "Here is a file",
      uploads: [
        {
          short_url: "upload://abc123.png",
          original_filename: "screenshot.png",
          extension: "png",
          width: 400,
          height: 300,
        },
      ],
      inProgressUploadsCount: 0,
    });

    assert.true(rawSent.includes("Here is a file"), "raw text preserved");
    assert.true(
      rawSent.includes("upload://abc123.png"),
      "upload markdown appended"
    );
  });

  test("loading state flips around the request", async function (assert) {
    const service = getOwner(this).lookup("service:ai-bot-docked-submit");
    pretender.post("/posts.json", () => response(200, { id: 1, topic_id: 42 }));

    assert.false(service.loading, "initially not loading");

    const promise = service.submitReply({
      topicId: 42,
      raw: "Long enough message body",
      uploads: [],
      inProgressUploadsCount: 0,
    });

    assert.true(service.loading, "loading while in-flight");
    await promise;
    assert.false(service.loading, "cleared after response");
  });
});
