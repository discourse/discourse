/*global expect:true describe:true it:true beforeEach:true afterEach:true spyOn:true */

describe("Discourse.ClickTrack", function() {

  var track = Discourse.ClickTrack.trackClick,
      clickEvent,
      html = [
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
      '  </article>',
      '</div>'].join("\n");

  var generateClickEventOn = function(selector) {
    return $.Event("click", { currentTarget: $(selector)[0] });
  }

  beforeEach(function() {
    $('body').html(html);
  });

  afterEach(function() {
    $('#topic').remove();
  });

  describe("lightboxes", function() {

    beforeEach(function() {
      clickEvent = generateClickEventOn('.lightbox');
    });

    it("does not track clicks on lightboxes", function() {
      expect(track(clickEvent)).toBe(true);
    });

    it("does not call preventDefault", function() {
      spyOn(clickEvent, "preventDefault");
      track(clickEvent);
      expect(clickEvent.preventDefault).not.toHaveBeenCalled();
    });

  });

  it("calls preventDefault", function() {
    clickEvent = generateClickEventOn('a');
    spyOn(clickEvent, "preventDefault");
    track(clickEvent);
    expect(clickEvent.preventDefault).toHaveBeenCalled();
  });

  it("does not track clicks on back buttons", function() {
    clickEvent = generateClickEventOn('.back');
    expect(track(clickEvent)).toBe(true);
  });

  it("does not track clicks on quote buttons", function() {
    clickEvent = generateClickEventOn('.quote-other-topic');
    expect(track(clickEvent)).toBe(true);
  });

  it("removes the href and put it as a data attribute", function() {
    clickEvent = generateClickEventOn('a');
    track(clickEvent);
    var $link = $('a').first();
    expect($link.hasClass('no-href')).toBe(true);
    expect($link.data('href')).toEqual("http://www.google.com");
    expect($link.attr('href')).toBeUndefined();
    expect($link.data('auto-route')).toBe(true);
  });

  describe("badges", function() {

    it("does not update badge clicks on my own link", function() {
      spyOn(Discourse, "get").andReturn(314);
      track(generateClickEventOn('#with-badge'));
      var $badge = $('span.badge', $('#with-badge').first());
      expect(parseInt($badge.html(), 10)).toEqual(1);
    });

    it("does not update badge clicks on links in my own post", function() {
      spyOn(Discourse, "get").andReturn(3141);
      track(generateClickEventOn('#with-badge-but-not-mine'));
      var $badge = $('span.badge', $('#with-badge-but-not-mine').first());
      expect(parseInt($badge.html(), 10)).toEqual(1);
    });

    describe("oneboxes", function() {

      it("does not update badge clicks in oneboxes", function() {
        track(generateClickEventOn('#inside-onebox'));
        var $badge = $('span.badge', $('#inside-onebox').first());
        expect(parseInt($badge.html(), 10)).toEqual(1);
      });

      it("updates badge clicks in oneboxes when forced", function() {
        track(generateClickEventOn('#inside-onebox-forced'));
        var $badge = $('span.badge', $('#inside-onebox-forced').first());
        expect(parseInt($badge.html(), 10)).toEqual(2);
      });

    });

    it("updates badge clicks", function() {
      track(generateClickEventOn('#with-badge'));
      var $badge = $('span.badge', $('#with-badge').first());
      expect(parseInt($badge.html(), 10)).toEqual(2);
    });

  });

  describe("right click", function() {

    beforeEach(function(){
      clickEvent = generateClickEventOn('a');
      clickEvent.which = 3;
    });

    it("detects right clicks", function() {
      expect(track(clickEvent)).toBe(true);
    });

    it("changes the href", function() {
      track(clickEvent);
      var $link = $('a').first();
      expect($link.attr('href')).toEqual("http://www.google.com");
    });

    it("tracks external right clicks", function() {
      Discourse.SiteSettings.track_external_right_clicks = true;
      track(clickEvent);
      var $link = $('a').first();
      expect($link.attr('href')).toEqual("/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42");
      // reset
      Discourse.SiteSettings.track_external_right_clicks = false;
    });

  });

  describe("new tab", function() {

    beforeEach(function(){
      clickEvent = generateClickEventOn('a');
      spyOn(Discourse, 'ajax');
      spyOn(window, 'open');
    });

    it("opens in a new tab when pressing alt", function() {
      clickEvent.metaKey = true;
      expect(track(clickEvent)).toBe(false);
      expect(Discourse.ajax).toHaveBeenCalled();
      expect(window.open).toHaveBeenCalledWith('http://www.google.com', '_blank');
    });

    it("opens in a new tab when pressing ctrl", function() {
      clickEvent.ctrlKey = true;
      expect(track(clickEvent)).toBe(false);
      expect(Discourse.ajax).toHaveBeenCalled();
      expect(window.open).toHaveBeenCalledWith('http://www.google.com', '_blank');
    });

    it("opens in a new tab when middle clicking", function() {
      clickEvent.which = 2;
      expect(track(clickEvent)).toBe(false);
      expect(Discourse.ajax).toHaveBeenCalled();
      expect(window.open).toHaveBeenCalledWith('http://www.google.com', '_blank');
    });

  });

  it("tracks via AJAX if we're on the same site", function() {
    // setup
    clickEvent = generateClickEventOn('#same-site');
    spyOn(Discourse, 'ajax');
    spyOn(Discourse.URL, 'routeTo');
    spyOn(Discourse.URL, 'origin').andReturn('http://discuss.domain.com');
    // test
    expect(track(clickEvent)).toBe(false);
    expect(Discourse.ajax).toHaveBeenCalled();
    expect(Discourse.URL.routeTo).toHaveBeenCalledWith('http://discuss.domain.com');
  });

  describe("tracks via custom URL", function() {

    beforeEach(function() {
      clickEvent = generateClickEventOn('a');
    });

    it("in another window", function() {
      // spies
      spyOn(Discourse, 'get').andReturn(true);
      spyOn(window, 'open').andCallFake(function() { return { focus: function() {} } });
      spyOn(window, 'focus');
      // test
      expect(track(clickEvent)).toBe(false);
      expect(Discourse.get).toHaveBeenCalledWith('currentUser.external_links_in_new_tab');
      expect(window.open).toHaveBeenCalledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42', '_blank');
    });

    it("in the same window", function() {
      spyOn(Discourse.URL, 'redirectTo');
      expect(track(clickEvent)).toBe(false);
      expect(Discourse.URL.redirectTo).toHaveBeenCalledWith('/clicks/track?url=http%3A%2F%2Fwww.google.com&post_id=42');
    });

  });

});
