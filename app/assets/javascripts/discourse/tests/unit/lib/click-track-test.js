import { fixture, logIn } from "discourse/tests/helpers/qunit-helpers";
import { module, skip, test } from "qunit";
import ClickTrack from "discourse/lib/click-track";
import DiscourseURL from "discourse/lib/url";
import User from "discourse/models/user";
import pretender from "discourse/tests/helpers/create-pretender";
import sinon from "sinon";
import { setPrefix } from "discourse-common/lib/get-url";

const track = ClickTrack.trackClick;

function generateClickEventOn(selector) {
  return $.Event("click", { currentTarget: fixture(selector) });
}

module("Unit | Utility | click-track", function (hooks) {
  hooks.beforeEach(function () {
    logIn();

    let win = { focus: function () {} };
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

  skip("tracks internal URLs", async function (assert) {
    assert.expect(2);
    sinon.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

    const done = assert.async();
    pretender.post("/clicks/track", (request) => {
      assert.ok(
        request.requestBody,
        "url=http%3A%2F%2Fdiscuss.domain.com&post_id=42&topic_id=1337"
      );
      done();
    });

    assert.notOk(track(generateClickEventOn("#same-site")));
  });

  test("does not track elements with no href", async function (assert) {
    assert.ok(track(generateClickEventOn(".a-without-href")));
  });

  test("does not track attachments", async function (assert) {
    sinon.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

    pretender.post("/clicks/track", () => assert.ok(false));

    assert.notOk(track(generateClickEventOn(".attachment")));
    assert.ok(
      DiscourseURL.redirectTo.calledWith(
        "http://discuss.domain.com/uploads/default/1234/1532357280.txt"
      )
    );
  });

  test("routes to internal urls", async function (assert) {
    setPrefix("/forum");
    pretender.post("/clicks/track", () => [200, {}, ""]);
    await track(generateClickEventOn(".prefix-url"), null, {
      returnPromise: true,
    });
    assert.ok(DiscourseURL.routeTo.calledWith("/forum/thing"));
  });

  test("routes to absolute internal urls", async function (assert) {
    setPrefix("/forum");
    pretender.post("/clicks/track", () => [200, {}, ""]);
    await track(generateClickEventOn(".abs-prefix-url"), null, {
      returnPromise: true,
    });
    assert.ok(
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
    assert.ok(DiscourseURL.redirectAbsolute.calledWith("/thing"));
  });

  skip("tracks external URLs", async function (assert) {
    assert.expect(2);

    const done = assert.async();
    pretender.post("/clicks/track", (request) => {
      assert.ok(
        request.requestBody,
        "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
      );
      done();
    });

    assert.notOk(track(generateClickEventOn("a")));
  });

  skip("tracks external URLs when opening in another window", async function (assert) {
    assert.expect(3);
    User.currentProp("user_option.external_links_in_new_tab", true);

    const done = assert.async();
    pretender.post("/clicks/track", (request) => {
      assert.ok(
        request.requestBody,
        "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
      );
      done();
    });

    assert.notOk(track(generateClickEventOn("a")));
    assert.ok(window.open.calledWith("http://www.google.com", "_blank"));
  });

  test("does not track clicks on lightboxes", async function (assert) {
    assert.notOk(track(generateClickEventOn(".lightbox")));
  });

  test("does not track clicks when forcibly disabled", async function (assert) {
    assert.notOk(track(generateClickEventOn(".no-track-link")));
  });

  test("does not track clicks on back buttons", async function (assert) {
    assert.notOk(track(generateClickEventOn(".back")));
  });

  test("does not track right clicks inside quotes", async function (assert) {
    const event = generateClickEventOn(".quote a:first-child");
    event.which = 3;
    assert.ok(track(event));
  });

  test("does not track clicks links in quotes", async function (assert) {
    User.currentProp("user_option.external_links_in_new_tab", true);
    assert.notOk(track(generateClickEventOn(".quote a:last-child")));
    assert.ok(window.open.calledWith("https://google.com/", "_blank"));
  });

  test("does not track clicks on hashtags for categories and tags", async function (assert) {
    assert.notOk(track(generateClickEventOn(".hashtag")));
    assert.notOk(track(generateClickEventOn(".hashtag-cooked")));
  });

  test("returns true for tracking mentions and group mentions so the card can appear", async function (assert) {
    assert.ok(track(generateClickEventOn(".mention")));
    assert.ok(track(generateClickEventOn(".mention-group")));
  });

  test("does not track clicks on mailto", async function (assert) {
    assert.ok(track(generateClickEventOn(".mailto")));
  });

  function badgeClickCount(assert, id, expected) {
    track(generateClickEventOn(`#${id}`));
    const badge = fixture(`#${id}`).querySelector("span.badge");
    assert.strictEqual(parseInt(badge.innerHTML, 10), expected);
  }

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

  function testOpenInANewTab(description, clickEventModifier) {
    test(description, async function (assert) {
      let clickEvent = generateClickEventOn("a");
      clickEventModifier(clickEvent);
      assert.ok(track(clickEvent));
      assert.notOk(clickEvent.defaultPrevented);
    });
  }

  testOpenInANewTab(
    "it opens in a new tab when pressing shift",
    (clickEvent) => {
      clickEvent.shiftKey = true;
    }
  );

  testOpenInANewTab(
    "it opens in a new tab when pressing meta",
    (clickEvent) => {
      clickEvent.metaKey = true;
    }
  );

  testOpenInANewTab(
    "it opens in a new tab when pressing ctrl",
    (clickEvent) => {
      clickEvent.ctrlKey = true;
    }
  );

  testOpenInANewTab("it opens in a new tab on middle click", (clickEvent) => {
    clickEvent.button = 2;
  });
});
