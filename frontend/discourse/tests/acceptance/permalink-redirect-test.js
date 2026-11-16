import { currentURL, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import EmbedMode from "discourse/lib/embed-mode";
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
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com", {
        replace: true,
      })
    );
  });
});

acceptance("Permalink check failure for /t/:slug_or_id", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/id_for/:slug", () => helper.response(404, {}));
    let permalinkRequests = 0;
    server.get("/permalink-check.json", () => {
      permalinkRequests++;
      if (permalinkRequests === 1) {
        return helper.response(500, {});
      }
      return helper.response({
        found: false,
        html: "<div class='page-not-found'>not found</div>",
      });
    });
  });

  test("falls back to the original 404 when the permalink check fails", async function (assert) {
    await visit("/t/some-slug-that-does-not-exist");

    assert.dom(".page-not-found").exists("the not found page is rendered");
  });
});

acceptance("Permalink redirect for /t/:slug (embedded)", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/id_for/:slug", () => helper.response(404, {}));
    server.get("/permalink-check.json", () =>
      helper.response({
        found: true,
        target_url: "https://www.example.com",
      })
    );
  });

  test("opens the external permalink in a new tab when embedded", async function (assert) {
    const originalEmbedMode = EmbedMode.enabled;
    EmbedMode.enabled = true;

    try {
      const open = sinon.stub(window, "open").returns(null);
      const redirectAbsolute = sinon.stub(DiscourseURL, "redirectAbsolute");

      await visitWithRedirects("/t/some-slug-that-does-not-exist");

      assert.true(open.calledWith("https://www.example.com", "_blank"));
      assert.false(redirectAbsolute.called);
    } finally {
      EmbedMode.enabled = originalEmbedMode;
    }
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
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com", {
        replace: true,
      })
    );
  });
});

acceptance("Permalink redirect for /t/:slug/:id (internal)", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/999999.json", () =>
      helper.response(404, {
        extras: { html: "<div class='page-not-found'>not found</div>" },
      })
    );
    server.get("/permalink-check.json", () =>
      helper.response({
        found: true,
        internal: true,
        target_url: "/t/internationalization-localization/280",
      })
    );
  });

  test("redirects within the router when the permalink targets an internal URL", async function (assert) {
    const redirect = sinon.stub(DiscourseURL, "redirectAbsolute");

    await visit("/t/some-slug-that-does-not-exist/999999");

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280"
    );
    assert.false(
      redirect.called,
      "internal permalinks must not trigger a full-page redirect"
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

acceptance("Permalink check failure for /t/:slug/:id", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/t/999999.json", () =>
      helper.response(404, {
        extras: { html: "<div class='page-not-found'>not found</div>" },
      })
    );
    server.get("/permalink-check.json", () => helper.response(500, {}));
  });

  test("renders the server 404 page when the permalink check fails", async function (assert) {
    await visit("/t/some-slug-that-does-not-exist/999999");

    assert.dom(".not-found").exists("the not found page is rendered");
  });
});

acceptance("Permalink redirect for /c/:slug", function (needs) {
  let requestedPath;

  needs.pretender((server, helper) => {
    server.get("/permalink-check.json", (request) => {
      requestedPath = request.queryParams.path;
      return helper.response({
        found: true,
        target_url: "https://www.example.com",
      });
    });
  });

  test("redirects when the category slug matches a permalink", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    await visitWithRedirects("/c/some-category-that-does-not-exist");

    assert.strictEqual(requestedPath, "/c/some-category-that-does-not-exist");
    assert.true(
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com", {
        replace: true,
      })
    );
  });
});

acceptance("Permalink redirect for /c/:slug/:id", function (needs) {
  let requestedPath;

  needs.pretender((server, helper) => {
    server.get("/permalink-check.json", (request) => {
      requestedPath = request.queryParams.path;
      return helper.response({
        found: true,
        target_url: "https://www.example.com",
      });
    });
  });

  test("redirects when the category slug/id matches a permalink", async function (assert) {
    sinon.stub(DiscourseURL, "redirectAbsolute");

    await visitWithRedirects("/c/some-category-that-does-not-exist/999999");

    assert.strictEqual(
      requestedPath,
      "/c/some-category-that-does-not-exist/999999"
    );
    assert.true(
      DiscourseURL.redirectAbsolute.calledWith("https://www.example.com", {
        replace: true,
      })
    );
  });
});

acceptance("Permalink not found for /c/:slug", function () {
  test("shows the 404 page when no permalink matches", async function (assert) {
    await visit("/c/some-category-that-does-not-exist/999999");

    assert.strictEqual(currentURL(), "/404");
  });
});

acceptance("Permalink check failure for /c/:slug", function (needs) {
  needs.pretender((server, helper) => {
    let permalinkRequests = 0;
    server.get("/permalink-check.json", () => {
      permalinkRequests++;
      if (permalinkRequests === 1) {
        return helper.response(500, {});
      }
      return helper.response({ found: false });
    });
  });

  test("shows the 404 page when the permalink check fails", async function (assert) {
    await visit("/c/some-category-that-does-not-exist");

    assert.strictEqual(currentURL(), "/404");
  });
});
