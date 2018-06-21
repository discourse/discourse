import DiscourseURL from "discourse/lib/url";
import ClickTrack from "discourse/lib/click-track";

var windowOpen, win, redirectTo;

QUnit.module("lib:click-track", {
  beforeEach() {
    // Prevent any of these tests from navigating away
    win = { focus: function() {} };
    redirectTo = sandbox.stub(DiscourseURL, "redirectTo");
    windowOpen = sandbox.stub(window, "open").returns(win);
    sandbox.stub(win, "focus");

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
          <aside class="quote">
            <a class="inside-quote" href="http://discuss.domain.com">foobar</a>
          </aside>
        </article>
      </div>`
    );
  }
});

var track = ClickTrack.trackClick;

// test
var generateClickEventOn = function(selector) {
  return $.Event("click", { currentTarget: fixture(selector)[0] });
};

QUnit.test("does not track clicks on lightboxes", function(assert) {
  var clickEvent = generateClickEventOn(".lightbox");
  sandbox.stub(clickEvent, "preventDefault");
  assert.ok(track(clickEvent));
  assert.ok(!clickEvent.preventDefault.calledOnce);
});

QUnit.test("it calls preventDefault when clicking on an a", function(assert) {
  var clickEvent = generateClickEventOn("a");
  sandbox.stub(clickEvent, "preventDefault");
  track(clickEvent);
  assert.ok(clickEvent.preventDefault.calledOnce);
  assert.ok(DiscourseURL.redirectTo.calledOnce);
});

QUnit.test("does not track clicks when forcibly disabled", function(assert) {
  assert.ok(track(generateClickEventOn(".no-track-link")));
});

QUnit.test("does not track clicks on back buttons", function(assert) {
  assert.ok(track(generateClickEventOn(".back")));
});

QUnit.test("does not track clicks in quotes", function(assert) {
  track(generateClickEventOn(".inside-quote"));
  assert.ok(DiscourseURL.redirectTo.calledWith("http://discuss.domain.com"));
});

QUnit.test("does not track clicks on category badges", assert => {
  assert.ok(track(generateClickEventOn(".hashtag")));
});

QUnit.test("does not track clicks on mailto", function(assert) {
  assert.ok(track(generateClickEventOn(".mailto")));
});

QUnit.test("removes the href and put it as a data attribute", function(assert) {
  track(generateClickEventOn("a"));

  var $link = fixture("a").first();
  assert.ok($link.hasClass("no-href"));
  assert.equal($link.data("href"), "http://www.google.com");
  assert.blank($link.attr("href"));
  assert.ok($link.data("auto-route"));
  assert.ok(DiscourseURL.redirectTo.calledOnce);
});

asyncTestDiscourse("restores the href after a while", function(assert) {
  assert.expect(1);

  track(generateClickEventOn("a"));

  const done = assert.async();
  setTimeout(function() {
    done();
    assert.equal(fixture("a").attr("href"), "http://www.google.com");
  }, 75);
});

var badgeClickCount = function(assert, id, expected) {
  track(generateClickEventOn("#" + id));
  var $badge = $("span.badge", fixture("#" + id).first());
  assert.equal(parseInt($badge.html(), 10), expected);
};

QUnit.test("does not update badge clicks on my own link", function(assert) {
  sandbox
    .stub(Discourse.User, "currentProp")
    .withArgs("id")
    .returns(314);
  badgeClickCount(assert, "with-badge", 1);
});

QUnit.test("does not update badge clicks in my own post", function(assert) {
  sandbox
    .stub(Discourse.User, "currentProp")
    .withArgs("id")
    .returns(3141);
  badgeClickCount(assert, "with-badge-but-not-mine", 1);
});

QUnit.test("updates badge counts correctly", function(assert) {
  badgeClickCount(assert, "inside-onebox", 1);
  badgeClickCount(assert, "inside-onebox-forced", 2);
  badgeClickCount(assert, "with-badge", 2);
});

var trackRightClick = function() {
  var clickEvent = generateClickEventOn("a");
  clickEvent.which = 3;
  return track(clickEvent);
};

QUnit.test("right clicks change the href", function(assert) {
  assert.ok(trackRightClick());
  assert.equal(
    fixture("a")
      .first()
      .prop("href"),
    "http://www.google.com/"
  );
});

QUnit.test("right clicks are tracked", function(assert) {
  Discourse.SiteSettings.track_external_right_clicks = true;
  trackRightClick();
  assert.equal(
    fixture("a")
      .first()
      .attr("href"),
    "/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
  );
});

QUnit.test("preventDefault is not called for right clicks", function(assert) {
  var clickEvent = generateClickEventOn("a");
  clickEvent.which = 3;
  sandbox.stub(clickEvent, "preventDefault");
  assert.ok(track(clickEvent));
  assert.ok(!clickEvent.preventDefault.calledOnce);
});

var testOpenInANewTab = function(description, clickEventModifier) {
  test(description, function(assert) {
    var clickEvent = generateClickEventOn("a");
    clickEventModifier(clickEvent);
    sandbox.stub(clickEvent, "preventDefault");
    assert.ok(track(clickEvent));
    assert.ok(!clickEvent.preventDefault.calledOnce);
  });
};

testOpenInANewTab("it opens in a new tab when pressing shift", function(
  clickEvent
) {
  clickEvent.shiftKey = true;
});

testOpenInANewTab("it opens in a new tab when pressing meta", function(
  clickEvent
) {
  clickEvent.metaKey = true;
});

testOpenInANewTab("it opens in a new tab when pressing ctrl", function(
  clickEvent
) {
  clickEvent.ctrlKey = true;
});

testOpenInANewTab("it opens in a new tab on middle click", function(
  clickEvent
) {
  clickEvent.button = 2;
});

QUnit.test("tracks via AJAX if we're on the same site", function(assert) {
  sandbox.stub(DiscourseURL, "routeTo");
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  assert.ok(!track(generateClickEventOn("#same-site")));
  assert.ok(DiscourseURL.routeTo.calledOnce);
});

QUnit.test("does not track via AJAX for attachments", function(assert) {
  sandbox.stub(DiscourseURL, "routeTo");
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  assert.ok(!track(generateClickEventOn(".attachment")));
  assert.ok(DiscourseURL.redirectTo.calledOnce);
});

QUnit.test("tracks custom urls when opening in another window", function(
  assert
) {
  var clickEvent = generateClickEventOn("a");
  sandbox
    .stub(Discourse.User, "currentProp")
    .withArgs("external_links_in_new_tab")
    .returns(true);
  assert.ok(!track(clickEvent));
  assert.ok(
    windowOpen.calledWith(
      "/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337",
      "_blank"
    )
  );
});

QUnit.test("tracks custom urls when opening in another window", function(
  assert
) {
  var clickEvent = generateClickEventOn("a");
  assert.ok(!track(clickEvent));
  assert.ok(
    redirectTo.calledWith(
      "/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337"
    )
  );
});
