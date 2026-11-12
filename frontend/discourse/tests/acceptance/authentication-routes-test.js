import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import DiscourseURL from "discourse/lib/url";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Authentication routes - logged in", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    const topic = cloneJSON(topicFixtures["/t/280/1.json"]);
    topic.post_stream.posts[0].cooked =
      '<p><a href="/login">Log in</a> <a href="/signup">Sign up</a> <a href="/login?redirect=%2Fmy%2Fpreferences">Log in with a destination</a></p>';

    server.get("/t/280.json", () => helper.response(topic));
    server.get("/t/280/:post_number.json", () => helper.response(topic));
  });

  test("login links with a destination use the server redirect validation", async function (assert) {
    const redirect = sinon.stub(DiscourseURL, "redirectTo");
    await visit("/t/internationalization-localization/280");
    await click('.cooked a[href^="/login?redirect="]');

    assert.true(
      redirect.calledWithExactly("/login?redirect=%2Fmy%2Fpreferences"),
      "Rails handles the login redirect"
    );
    assert.dom("#login-account-name").doesNotExist("login form is not shown");
  });

  for (const route of ["login", "signup"]) {
    test(`visiting ${route} directly redirects home`, async function (assert) {
      await visit(`/${route}`);

      assert.strictEqual(currentURL(), "/", "redirects to the homepage");
      assert.dom("#login-account-name").doesNotExist("login form is not shown");
      assert.dom("#new-account-email").doesNotExist("signup form is not shown");
    });

    test(`clicking a ${route} link in a post redirects home`, async function (assert) {
      await visit("/t/internationalization-localization/280");
      await click(`.cooked a[href="/${route}"]`);

      assert.strictEqual(currentURL(), "/", "redirects to the homepage");
      assert.dom("#login-account-name").doesNotExist("login form is not shown");
      assert.dom("#new-account-email").doesNotExist("signup form is not shown");
    });

    test(`visiting ${route} on a login-required site redirects home`, async function (assert) {
      this.siteSettings.login_required = true;

      await visit(`/${route}`);

      assert.strictEqual(currentURL(), "/", "redirects to the homepage");
      assert.dom("#login-account-name").doesNotExist("login form is not shown");
      assert.dom("#new-account-email").doesNotExist("signup form is not shown");
    });
  }
});
