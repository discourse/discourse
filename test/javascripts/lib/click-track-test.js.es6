import { later } from "@ember/runloop";
import DiscourseURL from "discourse/lib/url";
import ClickTrack from "discourse/lib/click-track";
import { fixture, logIn } from "helpers/qunit-helpers";

QUnit.module("lib:click-track", {
  beforeEach() {
    logIn();

    let win = { focus: function() {} };
    sandbox.stub(window, "open").returns(win);
    sandbox.stub(win, "focus");

    sandbox.stub(DiscourseURL, "routeTo");
    sandbox.stub(DiscourseURL, "redirectTo");

    sessionStorage.clear();

    fixture().html(
      `<div id="topic" data-topic-id="1337">
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
          <a class="hashtag" href="http://discuss.domain.com">#hashtag</a>
          <a class="mailto" href="mailto:foo@bar.com">email-me</a>
          <a class="a-without-href">no href</a>
          <aside class="quote">
            <a href="https://discuss.domain.com/t/welcome-to-meta-discourse-org/1/30">foo</a>
            <a href="https://google.com">bar</a>
          </aside>
        </article>
      </div>`
    );
  }
});

var track = ClickTrack.trackClick;

function generateClickEventOn(selector) {
  return $.Event("click", { currentTarget: fixture(selector).first() });
}

QUnit.skip("tracks internal URLs", async assert => {
  assert.expect(2);
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  const done = assert.async();
  /* global server */
  server.post("/clicks/track", request => {
    assert.ok(
      request.requestBody,
      "url=http%3A%2F%2Fdiscuss.domain.com&post_id=42&topic_id=1337"
    );
    done();
  });

  assert.notOk(track(generateClickEventOn("#same-site")));
});

QUnit.skip("does not track elements with no href", async assert => {
  assert.ok(track(generateClickEventOn(".a-without-href")));
});

QUnit.skip("does not track attachments", async assert => {
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  /* global server */
  server.post("/clicks/track", () => assert.ok(false));

  assert.notOk(track(generateClickEventOn(".attachment")));
  assert.ok(
    DiscourseURL.redirectTo.calledWith(
      "http://discuss.domain.com/uploads/default/1234/1532357280.txt"
    )
  );
});

QUnit.skip("tracks external URLs", async assert => {
  assert.expect(2);

  const done = assert.async();
  /* global server */
  server.post("/clicks/track", request => {
    assert.ok(
      request.requestBody,
      "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
    );
    done();
  });

  assert.notOk(track(generateClickEventOn("a")));
});

QUnit.skip(
  "tracks external URLs when opening in another window",
  async assert => {
    assert.expect(3);
    Discourse.User.currentProp("external_links_in_new_tab", true);

    const done = assert.async();
    /* global server */
    server.post("/clicks/track", request => {
      assert.ok(
        request.requestBody,
        "url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
      );
      done();
    });

    assert.notOk(track(generateClickEventOn("a")));
    assert.ok(window.open.calledWith("http://www.google.com", "_blank"));
  }
);

QUnit.skip("does not track clicks on lightboxes", async assert => {
  assert.notOk(track(generateClickEventOn(".lightbox")));
});

QUnit.skip("does not track clicks when forcibly disabled", async assert => {
  assert.notOk(track(generateClickEventOn(".no-track-link")));
});

QUnit.skip("does not track clicks on back buttons", async assert => {
  assert.notOk(track(generateClickEventOn(".back")));
});

QUnit.skip("does not track right clicks inside quotes", async assert => {
  const event = generateClickEventOn(".quote a:first-child");
  event.which = 3;
  assert.ok(track(event));
});

QUnit.skip("does not track clicks links in quotes", async assert => {
  Discourse.User.currentProp("external_links_in_new_tab", true);
  assert.notOk(track(generateClickEventOn(".quote a:last-child")));
  assert.ok(window.open.calledWith("https://google.com", "_blank"));
});

QUnit.skip("does not track clicks on category badges", async assert => {
  assert.notOk(track(generateClickEventOn(".hashtag")));
});

QUnit.skip("does not track clicks on mailto", async assert => {
  assert.ok(track(generateClickEventOn(".mailto")));
});

QUnit.skip("removes the href and put it as a data attribute", async assert => {
  Discourse.User.currentProp("external_links_in_new_tab", true);

  assert.notOk(track(generateClickEventOn("a")));

  var $link = fixture("a").first();
  assert.ok($link.hasClass("no-href"));
  assert.equal($link.data("href"), "http://www.google.com");
  assert.blank($link.attr("href"));
  assert.ok($link.data("auto-route"));
  assert.ok(window.open.calledWith("http://www.google.com", "_blank"));
});

QUnit.skip("restores the href after a while", async assert => {
  assert.expect(2);

  assert.notOk(track(generateClickEventOn("a")));

  assert.timeout(75);

  const done = assert.async();
  later(() => {
    assert.equal(fixture("a").attr("href"), "http://www.google.com");
    done();
  });
});

function badgeClickCount(assert, id, expected) {
  track(generateClickEventOn("#" + id));
  var $badge = $("span.badge", fixture("#" + id).first());
  assert.equal(parseInt($badge.html(), 10), expected);
}

QUnit.skip("does not update badge clicks on my own link", async assert => {
  sandbox
    .stub(Discourse.User, "currentProp")
    .withArgs("id")
    .returns(314);
  badgeClickCount(assert, "with-badge", 1);
});

QUnit.skip("does not update badge clicks in my own post", async assert => {
  sandbox
    .stub(Discourse.User, "currentProp")
    .withArgs("id")
    .returns(3141);
  badgeClickCount(assert, "with-badge-but-not-mine", 1);
});

QUnit.skip("updates badge counts correctly", async assert => {
  badgeClickCount(assert, "inside-onebox", 1);
  badgeClickCount(assert, "inside-onebox-forced", 2);
  badgeClickCount(assert, "with-badge", 2);
});

function testOpenInANewTab(description, clickEventModifier) {
  QUnit.skip(description, async assert => {
    var clickEvent = generateClickEventOn("a");
    clickEventModifier(clickEvent);
    assert.ok(track(clickEvent));
    assert.notOk(clickEvent.defaultPrevented);
  });
}

testOpenInANewTab("it opens in a new tab when pressing shift", clickEvent => {
  clickEvent.shiftKey = true;
});

testOpenInANewTab("it opens in a new tab when pressing meta", clickEvent => {
  clickEvent.metaKey = true;
});

testOpenInANewTab("it opens in a new tab when pressing ctrl", clickEvent => {
  clickEvent.ctrlKey = true;
});

testOpenInANewTab("it opens in a new tab on middle click", clickEvent => {
  clickEvent.button = 2;
});
