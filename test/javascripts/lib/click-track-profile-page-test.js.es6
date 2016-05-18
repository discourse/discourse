import { blank } from 'helpers/qunit-helpers';
import DiscourseURL from "discourse/lib/url";
import ClickTrack from "discourse/lib/click-track";

var windowOpen,
    win,
    redirectTo;

module("lib:click-track-profile-page", {
  setup: function() {

    // Prevent any of these tests from navigating away
    win = {focus: function() { } };
    redirectTo = sandbox.stub(DiscourseURL, "redirectTo");
    sandbox.stub(Discourse, "ajax");
    windowOpen = sandbox.stub(window, "open").returns(win);
    sandbox.stub(win, "focus");

    fixture().html(
      `<p class="excerpt first" data-post-id="42" data-topic-id="1337" data-user-id="3141">
        <a href="http://www.google.com">google.com</a>
        <a class="lightbox back quote-other-topic" href="http://www.google.com">google.com</a>
        <div class="onebox-result">
          <a id="inside-onebox" href="http://www.google.com">google.com<span class="badge">1</span></a>
          <a id="inside-onebox-forced" class="track-link" href="http://www.google.com">google.com<span class="badge">1</span></a>
        </div>
        <a class="no-track-link" href="http://www.google.com">google.com</a>
        <a id="same-site" href="http://discuss.domain.com">forum</a>
        <a class="attachment" href="http://discuss.domain.com/uploads/default/1234/1532357280.txt">log.txt</a>
        <a class="hashtag" href="http://discuss.domain.com">#hashtag</a>
      </p>
      <p class="excerpt second" data-post-id="24" data-topic-id="7331" data-user-id="1413">
        <a href="http://www.google.com">google.com</a>
        <a class="lightbox back quote-other-topic" href="http://www.google.com">google.com</a>
        <div class="onebox-result">
          <a id="inside-onebox" href="http://www.google.com">google.com<span class="badge">1</span></a>
          <a id="inside-onebox-forced" class="track-link" href="http://www.google.com">google.com<span class="badge">1</span></a>
        </div>
        <a class="no-track-link" href="http://www.google.com">google.com</a>
        <a id="same-site" href="http://discuss.domain.com">forum</a>
        <a class="attachment" href="http://discuss.domain.com/uploads/default/1234/1532357280.txt">log.txt</a>
        <a class="hashtag" href="http://discuss.domain.com">#hashtag</a>
      </p>`);
  }
});

var track = ClickTrack.trackClick;

// test
var generateClickEventOn = function(selector) {
  return $.Event("click", { currentTarget: fixture(selector)[0] });
};

test("does not track clicks on lightboxes", function() {
  var clickEvent = generateClickEventOn('.lightbox');
  sandbox.stub(clickEvent, "preventDefault");
  ok(track(clickEvent));
  ok(!clickEvent.preventDefault.calledOnce);
});

test("it calls preventDefault when clicking on an a", function() {
  var clickEvent = generateClickEventOn('a');
  sandbox.stub(clickEvent, "preventDefault");
  track(clickEvent);
  ok(clickEvent.preventDefault.calledOnce);
  ok(DiscourseURL.redirectTo.calledOnce);
});

test("does not track clicks when forcibly disabled", function() {
  ok(track(generateClickEventOn('.no-track-link')));
});

test("does not track clicks on back buttons", function() {
  ok(track(generateClickEventOn('.back')));
});

test("does not track clicks on quote buttons", function() {
  ok(track(generateClickEventOn('.quote-other-topic')));
});

test("does not track clicks on category badges", () => {
  ok(track(generateClickEventOn('.hashtag')));
});

test("removes the href and put it as a data attribute", function() {
  track(generateClickEventOn('a'));

  var $link = fixture('a').first();
  ok($link.hasClass('no-href'));
  equal($link.data('href'), 'http://www.google.com');
  blank($link.attr('href'));
  ok($link.data('auto-route'));
  ok(DiscourseURL.redirectTo.calledOnce);
});

asyncTestDiscourse("restores the href after a while", function() {
  expect(1);

  track(generateClickEventOn('a'));

  setTimeout(function() {
    start();
    equal(fixture('a').attr('href'), "http://www.google.com");
  }, 75);
});

var trackRightClick = function(target) {
  var clickEvent = generateClickEventOn(target);
  clickEvent.which = 3;
  return track(clickEvent);
};

test("right clicks change the href", function() {
  ok(trackRightClick('a'));
  equal(fixture('a').first().prop('href'), "http://www.google.com/");
});

test("right clicks are tracked", function() {
  Discourse.SiteSettings.track_external_right_clicks = true;
  trackRightClick('a');
  equal(fixture('.first a').first().attr('href'), "/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337");
});

test("right clicks are tracked for second excerpt", function() {
  Discourse.SiteSettings.track_external_right_clicks = true;
  trackRightClick('.second a');
  equal(fixture('.second a').first().attr('href'), "/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=24&topic_id=7331");
});

test("preventDefault is not called for right clicks", function() {
  var clickEvent = generateClickEventOn('a');
  clickEvent.which = 3;
  sandbox.stub(clickEvent, "preventDefault");
  ok(track(clickEvent));
  ok(!clickEvent.preventDefault.calledOnce);
});

var testOpenInANewTab = function(description, clickEventModifier) {
  test(description, function() {
    var clickEvent = generateClickEventOn('a');
    clickEventModifier(clickEvent);
    sandbox.stub(clickEvent, "preventDefault");
    ok(track(clickEvent));
    ok(Discourse.ajax.calledOnce);
    ok(!clickEvent.preventDefault.calledOnce);
  });
};

testOpenInANewTab("it opens in a new tab when pressing shift", function(clickEvent) {
  clickEvent.shiftKey = true;
});

testOpenInANewTab("it opens in a new tab when pressing meta", function(clickEvent) {
  clickEvent.metaKey = true;
});

testOpenInANewTab("it opens in a new tab when pressing ctrl", function(clickEvent) {
  clickEvent.ctrlKey = true;
});

testOpenInANewTab("it opens in a new tab on middle click", function(clickEvent) {
  clickEvent.button = 2;
});

test("tracks via AJAX if we're on the same site", function() {
  sandbox.stub(DiscourseURL, "routeTo");
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  ok(!track(generateClickEventOn('#same-site')));
  ok(Discourse.ajax.calledOnce);
  ok(DiscourseURL.routeTo.calledOnce);
});

test("does not track via AJAX for attachments", function() {
  sandbox.stub(DiscourseURL, "routeTo");
  sandbox.stub(DiscourseURL, "origin").returns("http://discuss.domain.com");

  ok(!track(generateClickEventOn('.attachment')));
  ok(DiscourseURL.redirectTo.calledOnce);
});

test("tracks custom urls when opening in another window", function() {
  var clickEvent = generateClickEventOn('a');
  sandbox.stub(Discourse.User, "currentProp").withArgs('external_links_in_new_tab').returns(true);
  ok(!track(clickEvent));
  ok(windowOpen.calledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337', '_blank'));
});

test("tracks custom urls on second excerpt when opening in another window", function() {
  var clickEvent = generateClickEventOn('.second a');
  sandbox.stub(Discourse.User, "currentProp").withArgs('external_links_in_new_tab').returns(true);
  ok(!track(clickEvent));
  ok(windowOpen.calledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=24&topic_id=7331', '_blank'));
});

test("tracks custom urls when opening in another window", function() {
  var clickEvent = generateClickEventOn('a');
  ok(!track(clickEvent));
  ok(redirectTo.calledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42&topic_id=1337'));
});

test("tracks custom urls on second excerpt when opening in another window", function() {
  var clickEvent = generateClickEventOn('.second a');
  ok(!track(clickEvent));
  ok(redirectTo.calledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=24&topic_id=7331'));
});
