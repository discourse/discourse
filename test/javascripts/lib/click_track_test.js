module("Discourse.ClickTrack", {
  setup: function() {

    // Prevent any of these tests from navigating away
    this.win = {focus: function() { } };
    this.redirectTo = sinon.stub(Discourse.URL, "redirectTo");
    sinon.stub(Discourse, "ajax");
    this.windowOpen = sinon.stub(window, "open").returns(this.win);
    sinon.stub(this.win, "focus");

    fixture().html([
      '<div id="topic" id="1337">',
      '  <article data-post-id="42" data-user-id="3141">',
      '    <a href="http://www.google.com">google.com</a>',
      '    <a class="lightbox back quote-other-topic" href="http://www.google.com">google.com</a>',
      '    <a id="with-badge" data-user-id="314" href="http://www.google.com">google.com<span class="badge">1</span></a>',
      '    <a id="with-badge-but-not-mine" href="http://www.google.com">google.com<span class="badge">1</span></a>',
      '    <div class="onebox-result">',
      '      <a id="inside-onebox" href="http://www.google.com">google.com<span class="badge">1</span></a>',
      '      <a id="inside-onebox-forced" class="track-link" href="http://www.google.com">google.com<span class="badge">1</span></a>',
      '    </div>',
      '    <a id="same-site" href="http://discuss.domain.com">forum</a>',
      '    <a class="attachment" href="http://discuss.domain.com/uploads/default/1234/1532357280.txt">log.txt</a>',
      '  </article>',
      '</div>'].join("\n"));
  },

  teardown: function() {
    Discourse.URL.redirectTo.restore();
    Discourse.ajax.restore();
    window.open.restore();
    this.win.focus.restore();
  }
});

var track = Discourse.ClickTrack.trackClick;

// test
var generateClickEventOn = function(selector) {
  return $.Event("click", { currentTarget: fixture(selector)[0] });
};

test("does not track clicks on lightboxes", function() {
  var clickEvent = generateClickEventOn('.lightbox');
  this.stub(clickEvent, "preventDefault");
  ok(track(clickEvent));
  ok(!clickEvent.preventDefault.calledOnce);
});

test("it calls preventDefault when clicking on an a", function() {
  var clickEvent = generateClickEventOn('a');
  this.stub(clickEvent, "preventDefault");
  track(clickEvent);
  ok(clickEvent.preventDefault.calledOnce);
  ok(Discourse.URL.redirectTo.calledOnce);
});

test("does not track clicks on back buttons", function() {
  ok(track(generateClickEventOn('.back')));
});

test("does not track clicks on quote buttons", function() {
  ok(track(generateClickEventOn('.quote-other-topic')));
});

test("removes the href and put it as a data attribute", function() {
  track(generateClickEventOn('a'));

  var $link = fixture('a').first();
  ok($link.hasClass('no-href'));
  equal($link.data('href'), 'http://www.google.com');
  blank($link.attr('href'));
  ok($link.data('auto-route'));
  ok(Discourse.URL.redirectTo.calledOnce);
});


var badgeClickCount = function(id, expected) {
  track(generateClickEventOn('#' + id));
  var $badge = $('span.badge', fixture('#' + id).first());
  equal(parseInt($badge.html(), 10), expected);
};

test("does not update badge clicks on my own link", function() {
  this.stub(Discourse.User, 'currentProp').withArgs('id').returns(314);
  badgeClickCount('with-badge', 1);
});

test("does not update badge clicks in my own post", function() {
  this.stub(Discourse.User, 'currentProp').withArgs('id').returns(3141);
  badgeClickCount('with-badge-but-not-mine', 1);
});

test("updates badge counts correctly", function() {
  badgeClickCount('inside-onebox', 1);
  badgeClickCount('inside-onebox-forced', 2);
  badgeClickCount('with-badge', 2);
});

var trackRightClick = function() {
  var clickEvent = generateClickEventOn('a');
  clickEvent.which = 3;
  return track(clickEvent);
};

test("right clicks change the href", function() {
  ok(trackRightClick());
  equal(fixture('a').first().prop('href'), "http://www.google.com/");
});

test("right clicks are tracked", function() {
  Discourse.SiteSettings.track_external_right_clicks = true;
  trackRightClick();
  equal(fixture('a').first().attr('href'), "/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42");
});

test("preventDefault is not called for right clicks", function() {
  var clickEvent = generateClickEventOn('a');
  clickEvent.which = 3;
  this.stub(clickEvent, "preventDefault");
  ok(track(clickEvent));
  ok(!clickEvent.preventDefault.calledOnce);
});

var testOpenInANewTab = function(description, clickEventModifier) {
  test(description, function() {
    var clickEvent = generateClickEventOn('a');
    clickEventModifier(clickEvent);
    this.stub(clickEvent, "preventDefault");
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
  clickEvent.which = 2;
});

test("tracks via AJAX if we're on the same site", function() {
  this.stub(Discourse.URL, "routeTo");
  this.stub(Discourse.URL, "origin").returns("http://discuss.domain.com");

  ok(!track(generateClickEventOn('#same-site')));
  ok(Discourse.ajax.calledOnce);
  ok(Discourse.URL.routeTo.calledOnce);
});

test("does not track via AJAX for attachments", function() {
  this.stub(Discourse.URL, "routeTo");
  this.stub(Discourse.URL, "origin").returns("http://discuss.domain.com");

  ok(!track(generateClickEventOn('.attachment')));
  ok(Discourse.URL.redirectTo.calledOnce);
});

test("tracks custom urls when opening in another window", function() {
  var clickEvent = generateClickEventOn('a');
  this.stub(Discourse.User, "currentProp").withArgs('external_links_in_new_tab').returns(true);
  ok(!track(clickEvent));
  ok(this.windowOpen.calledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42', '_blank'));
});

test("tracks custom urls when opening in another window", function() {
  var clickEvent = generateClickEventOn('a');
  ok(!track(clickEvent));
  ok(this.redirectTo.calledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42'));
});
