import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("External Permalink Redirect via XHR", function (needs) {
  needs.pretender((server) => {
    server.get("/t/99.json", () => [
      200,
      { "Discourse-Xhr-Redirect": "true", "Content-Type": "text/plain" },
      "https://www.example.com",
    ]);
  });

  test("redirects to external URL when topic has an external permalink", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    await visit("/t/a-deleted-topic/99");

    assert.true(
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com", {
        replace: true,
      })
    );
  });
});
