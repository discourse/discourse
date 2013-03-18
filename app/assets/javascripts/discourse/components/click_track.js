/**
  Used for tracking when the user clicks on a link

  @class ClickTrack
  @namespace Discourse
  @module Discourse
**/
Discourse.ClickTrack = {

  /**
    Track a click on a link

    @method trackClick
    @param {jQuery.Event} e The click event that occurred
  **/
  trackClick: function(e) {
    var $a, $article, $badge, count, destination, href, ownLink, postId, topicId, trackingUrl, userId;
    $a = $(e.currentTarget);
    if ($a.hasClass('lightbox')) {
      return;
    }
    e.preventDefault();

    // We don't track clicks on quote back buttons
    if ($a.hasClass('back') || $a.hasClass('quote-other-topic')) return true;

    // Remove the href, put it as a data attribute
    if (!$a.data('href')) {
      $a.addClass('no-href');
      $a.data('href', $a.attr('href'));
      $a.attr('href', null);
      // Don't route to this URL
      $a.data('auto-route', true);
    }

    href = $a.data('href');
    $article = $a.closest('article');
    postId = $article.data('post-id');
    topicId = $('#topic').data('topic-id');
    userId = $a.data('user-id');
    if (!userId) {
      userId = $article.data('user-id');
    }
    ownLink = userId && (userId === Discourse.get('currentUser.id'));

    // Build a Redirect URL
    trackingUrl = Discourse.getURL("/clicks/track?url=" + encodeURIComponent(href));
    if (postId && (!$a.data('ignore-post-id'))) {
      trackingUrl += "&post_id=" + encodeURI(postId);
    }
    if (topicId) {
      trackingUrl += "&topic_id=" + encodeURI(topicId);
    }

    // Update badge clicks unless it's our own
    if (!ownLink) {
      $badge = $('span.badge', $a);
      if ($badge.length === 1) {
        count = parseInt($badge.html(), 10);
        $badge.html(count + 1);
      }
    }

    // If they right clicked, change the destination href
    if (e.which === 3) {
      destination = Discourse.SiteSettings.track_external_right_clicks ? trackingUrl : href;
      $a.attr('href', destination);
      return true;
    }

    // if they want to open in a new tab, do an AJAX request
    if (e.metaKey || e.ctrlKey || e.which === 2) {
      $.get(Discourse.getURL("/clicks/track"), {
        url: href,
        post_id: postId,
        topic_id: topicId,
        redirect: false
      });
      window.open(href, '_blank');
      return false;
    }

    // If we're on the same site, use the router and track via AJAX
    if (href.indexOf(window.location.origin) === 0) {
      $.get(Discourse.getURL("/clicks/track"), {
        url: href,
        post_id: postId,
        topic_id: topicId,
        redirect: false
      });
      Discourse.URL.routeTo(href);
      return false;
    }

    // Otherwise, use a custom URL with a redirect
    if (Discourse.get('currentUser.external_links_in_new_tab')) {
      var win = window.open(trackingUrl, '_blank');
      win.focus();
    }
    else {
      window.location = trackingUrl;
    }

    return false;
  }
};


