import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import ClickTrack from "discourse/lib/click-track";
import DiscourseURL from "discourse/lib/url";
import User from "discourse/models/user";
import pretender from "discourse/tests/helpers/create-pretender";
import { fixture, logIn } from "discourse/tests/helpers/qunit-helpers";
import { setPrefix } from "discourse-common/lib/get-url";

const track = ClickTrack.trackClick;

function generateClickEventOn(selector) {
  const event = new MouseEvent("click");
  sinon.stub(event, "currentTarget").get(() => fixture(selector));
  return event;
}

function badgeClickCount(assert, id, expected) {
  track(generateClickEventOn(`#${id}`));
  assert.dom("span.badge", fixture(`#${id}`)).hasHtml(String(expected));
}

function testOpenInANewTab(description, clickEventModifier) {
  test(description, async function (assert) {
    const clickEvent = generateClickEventOn("a");
    clickEventModifier(clickEvent);
    assert.true(track(clickEvent));
    assert.false(clickEvent.defaultPrevented);
  });
}

module("Unit | Utility | click-track", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    logIn();

    const win = { focus: function () {} };
    sinon.stub(window, "open").returns(win);
    sinon.stub(win, "focus");

    sinon.stub(DiscourseURL, "routeTo");
    sinon.stub(DiscourseURL, "redirectTo");

    sessionStorage.clear();

    fixture().innerHTML = `<div id="topic" data-topic-id="1337">
        <article data-post-id="42" data-user-id="3141">
          <a href="http://www.google.com">google.com</a>
          <a class="lightbox back" href="http://www.google.fr">google.fr</a>
          <a id="with-badge" data-user-id="314" href="http://www.google.de">google.de<span class="badge">1</span></a>
          <a id="with-badge-but-not-mine" href="http://www.google.es">google.es<span class="badge">1</span></a>
          <div class="onebox-result">
            <a id="inside-onebox" href="http://www.google.co.uk">google.co.uk<span class="badge">1</span></a>
            <a id="inside-onebox-forced" class="track-link" href="http://www.google.at">google.at<span class="badge">1</span></a>
          </div>
          <a class="no-track-link" href="http://www.google.com.br">google.com.br</a>
          <a id="same-site" href="http://discuss.domain.com">forum</a>
          <a class="attachment" href="http://discuss.domain.com/uploads/default/1234/1532357280.txt">log.txt</a>
          <a class="hashtag" href="/c/staff/42">#hashtag</a>
          <a class="mention" href="/u/joe">@joe</a>
          <a class="hashtag-cooked" href="/c/staff/42" data-type="category" data-slug="staff"><svg class="fa d-icon d-icon-folder svg-icon svg-node"><use href="#folder"></use></svg><span>staff</span></a>
          <a class="mention-group" href="/g/support">@support</a>
          <a class="mailto" href="mailto:foo@bar.com">email-me</a>
          <a class="a-without-href">no href</a>
          <aside class="quote">
            <a href="https://discuss.domain.com/t/welcome-to-meta-discourse-org/1/30">foo</a>
            <a href="https://google.com">bar</a>
          </aside>
          <a class="prefix-url" href="/forum/thing">prefix link</a>
          <a class="abs-prefix-url" href="${window.location.origin}/forum/thing">prefix link</a>
          <a class="diff-prefix-url" href="/thing">diff prefix link</a>
        </article>
      </div>`;
  });

  test("tracks internal URLs", async function (assert) {
    pretender.get("/session/csrf", () => {
      assert.true(false, "should not request a csrf token");
    });

    sinon.stub(DiscourseURL, "origin").get(() => "http://discuss.domain.com");

    const done = assert.async();
    pretender.post("/clicks/track", (request) => {
      assert.strictEqual(
        request.requestBody,
        "url=http%3A%2F%2Fdiscuss.domain.com&post_id=42&topic_id=1337"
      );
      done();
      return [200, {}, ""];
    });

    assert.false(track(generateClickEventOn("#same-site")));
  });

  test("does not track elements with no href", async function (assert) {
    assert.true(track(generateClickEventOn(".a-without-href")));
  });

  test("does not track attachments", async function (assert) {
    sinon.stub(DiscourseURL, "origin").get(() => "http://discuss.domain.com");

    pretender.post("/clicks/track", () => assert.true(false));

    assert.false(track(generateClickEventOn(".attachment")));
    assert.true(
      DiscourseURL.redirectTo.calledWith(
        "http://discuss.domain.com/uploads/default/1234/1532357280.txt"
      )
    );
  });

  test("routes to internal urls", async function (assert) {
    setPrefix("/forum");

    pretender.get("/forum/session/csrf", () => {
      assert.true(false, "should not request a csrf token");
    });
    pretender.get("/session/csrf", () => {
      assert.true(false, "should not request a csrf token");
    });

    pretender.post("/clicks/track", () => {
      assert.step("tracking");
      return [200, {}, ""];
    });

    await track(generateClickEventOn(".prefix-url"), null, {
      returnPromise: true,
    });
    assert.true(DiscourseURL.routeTo.calledWith("/forum/thing"));
    assert.verifySteps(["tracking"]);
  });

  test("routes to absolute internal urls", async function (assert) {
    setPrefix("/forum");
    pretender.post("/clicks/track", () => [200, {}, ""]);

    await track(generateClickEventOn(".abs-prefix-url"), null, {
      returnPromise: true,
    });
    assert.true(
      DiscourseURL.routeTo.calledWith(window.location.origin + "/forum/thing")
    );
  });

  test("redirects to internal urls with a different prefix", async function (assert) {
    setPrefix("/forum");
    sinon.stub(DiscourseURL, "redirectAbsolute");

    pretender.post("/clicks/track", () => [200, {}, ""]);
    await track(generateClickEventOn(".diff-prefix-url"), null, {
      returnPromise: true,
    });
    assert.true(DiscourseURL.redirectAbsolute.calledWith("/thing"));
  });

  test("tracks external URLs", async function (assert) {
    const done = assert.async();
    pretender.post("/clicks/track", (request) => {
      assert.strictEqual(
        request.requestBody,
        "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
      );
      done();
      return [200, {}, ""];
    });

    assert.false(track(generateClickEventOn("a")));
  });

  test("tracks external URLs when opening in another window", async function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);

    const done = assert.async();
    pretender.post("/clicks/track", (request) => {
      assert.strictEqual(
        request.requestBody,
        "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
      );
      done();
      return [200, {}, ""];
    });

    assert.false(track(generateClickEventOn("a")));
    assert.true(window.open.calledWith("http://www.google.com/", "_blank"));
  });

  test("does not track clicks on lightboxes", async function (assert) {
    assert.false(track(generateClickEventOn(".lightbox")));
  });

  test("does not track clicks when forcibly disabled", async function (assert) {
    assert.false(track(generateClickEventOn(".no-track-link")));
  });

  test("does not track clicks on back buttons", async function (assert) {
    assert.false(track(generateClickEventOn(".back")));
  });

  test("does not track right clicks inside quotes", async function (assert) {
    const event = generateClickEventOn(".quote a:first-child");
    sinon.stub(event, "which").get(() => 3);
    assert.true(track(event));
  });

  test("does not track clicks links in quotes", async function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);
    assert.false(track(generateClickEventOn(".quote a:last-child")));
    assert.true(window.open.calledWith("https://google.com/", "_blank"));
  });

  test("does not track clicks on hashtags for categories and tags", async function (assert) {
    assert.false(track(generateClickEventOn(".hashtag")));
    assert.false(track(generateClickEventOn(".hashtag-cooked")));
  });

  test("returns true for tracking mentions and group mentions so the card can appear", async function (assert) {
    assert.true(track(generateClickEventOn(".mention")));
    assert.true(track(generateClickEventOn(".mention-group")));
  });

  test("does not track clicks on mailto", async function (assert) {
    assert.true(track(generateClickEventOn(".mailto")));
  });

  test("does not update badge clicks on my own link", async function (assert) {
    sinon.stub(User, "currentProp").withArgs("id").returns(314);
    badgeClickCount(assert, "with-badge", 1);
  });

  test("does not update badge clicks in my own post", async function (assert) {
    sinon.stub(User, "currentProp").withArgs("id").returns(3141);
    badgeClickCount(assert, "with-badge-but-not-mine", 1);
  });

  test("updates badge counts correctly", async function (assert) {
    badgeClickCount(assert, "inside-onebox", 1);
    badgeClickCount(assert, "inside-onebox-forced", 2);
    badgeClickCount(assert, "with-badge", 2);
  });

  testOpenInANewTab(
    "it opens in a new tab when pressing shift",
    (clickEvent) => {
      sinon.stub(clickEvent, "shiftKey").get(() => true);
    }
  );

  testOpenInANewTab(
    "it opens in a new tab when pressing meta",
    (clickEvent) => {
      sinon.stub(clickEvent, "metaKey").get(() => true);
    }
  );

  testOpenInANewTab(
    "it opens in a new tab when pressing ctrl",
    (clickEvent) => {
      sinon.stub(clickEvent, "ctrlKey").get(() => true);
    }
  );

  testOpenInANewTab("it opens in a new tab on middle click", (clickEvent) => {
    sinon.stub(clickEvent, "button").get(() => 2);
  });
});
