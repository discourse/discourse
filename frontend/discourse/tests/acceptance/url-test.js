import { currentURL, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import interceptClick from "discourse/lib/intercept-click";
import DiscourseURL, { clearRewrites } from "discourse/lib/url";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("DiscourseURL", function () {
  test("handleURL strips multiple slashes", async function (assert) {
    await visit("/");

    DiscourseURL.handleURL("/t//280");
    await settled();

    assert.strictEqual(
      currentURL(),
      "/t/internationalization-localization/280"
    );
    assert.dom("#topic-title").exists();
  });
});

acceptance("Link interception", function (needs) {
  needs.hooks.afterEach(clearRewrites);

  test("intercepts recognized links and leaves unknown same-origin URLs to the browser", async function (assert) {
    await visit("/");
    const routeTo = sinon.stub(DiscourseURL, "routeTo");
    const target = document.createElement("a");
    const preventDefault = sinon.spy();

    target.href = "/offline-documentation/guide?section=1#details";
    interceptClick({ target, preventDefault });
    assert.false(preventDefault.called);
    assert.false(routeTo.called);

    target.href = "/t/internationalization-localization/280?x=1#details";
    interceptClick({ target, preventDefault });
    assert.true(preventDefault.calledOnce);
    assert.true(routeTo.calledOnceWithExactly(target.getAttribute("href")));
  });

  test("continues to intercept an unknown link with a registered rewrite", async function (assert) {
    await visit("/");
    DiscourseURL.rewrite(/^\/forum-legacy(\/.*)$/, "/latest");
    const routeTo = sinon.stub(DiscourseURL, "routeTo");
    const target = document.createElement("a");
    const preventDefault = sinon.spy();

    target.href = "/forum-legacy/alias";
    interceptClick({ target, preventDefault });

    assert.true(preventDefault.calledOnce);
    assert.true(routeTo.calledOnceWithExactly("/forum-legacy/alias"));
  });
});
