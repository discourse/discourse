import { settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import DiscourseURL from "discourse/lib/url";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

/**
 * Workaround for https://github.com/tildeio/router.js/pull/335
 */
async function visitWithRedirects(url) {
  try {
    await visit(url);
  } catch (error) {
    const { message } = error;
    if (message !== "TransitionAborted") {
      throw error;
    }
    await settled();
  }
}

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

acceptance("Permalink redirect for /t/:slug_or_id", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/id_for/:slug", () => helper.response(404, {}));
    server.get("/permalink-check.json", () =>
      helper.response({
        found: true,
        target_url: "https://www.example.com",
      })
    );
  });

  test("redirects when the slug matches a permalink", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    await visitWithRedirects("/t/some-slug-that-does-not-exist");

    assert.true(
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com")
    );
  });
});

acceptance("Permalink redirect for /t/:slug/:id", function (needs) {
  let requestedPath;

  needs.pretender((server, helper) => {
    server.get("/t/999999.json", () =>
      helper.response(404, {
        extras: { html: "<div class='page-not-found'>not found</div>" },
      })
    );
    server.get("/permalink-check.json", (request) => {
      requestedPath = request.queryParams.path;
      return helper.response({
        found: true,
        target_url: "https://www.example.com",
      });
    });
  });

  test("redirects when the id-only lookup is a permalink hit", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    await visitWithRedirects("/t/some-slug-that-does-not-exist/999999");

    assert.strictEqual(
      requestedPath,
      "/t/some-slug-that-does-not-exist/999999"
    );
    assert.true(
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com")
    );
  });
});

acceptance("Permalink not found for /t/:slug/:id", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/999999.json", () =>
      helper.response(404, {
        extras: { html: "<div class='page-not-found'>not found</div>" },
      })
    );
  });

  test("renders the server 404 page when no permalink matches", async function (assert) {
    await visit("/t/some-slug-that-does-not-exist/999999");

    assert.dom(".not-found").exists("the not found page is rendered");
  });
});
