var ACCEPTABLE_BLOCKING_MS = 100;

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
    var $link = $(e.currentTarget);
    if ($link.hasClass('lightbox')) return true;

    // We don't track clicks on quote back buttons
    if ($link.hasClass('back') || $link.hasClass('quote-other-topic')) {
        e.preventDefault();
        return true;
    }

    // Don't route to this URL
    $link.data('auto-route', true);

    var href = $link.attr('href'),
        $article = $link.closest('article'),
        postId = $article.data('post-id'),
        topicId = $('#topic').data('topic-id'),
        userId = $link.data('user-id');

    if (!userId) userId = $article.data('user-id');

    var ownLink = userId && (userId === Discourse.User.currentProp('id')),
        trackingUrl = Discourse.getURL("/clicks/track?url=" + encodeURIComponent(href));
    if (postId && (!$link.data('ignore-post-id'))) {
      trackingUrl += "&post_id=" + encodeURI(postId);
    }
    if (topicId) {
      trackingUrl += "&topic_id=" + encodeURI(topicId);
    }

    // Update badge clicks unless it's our own
    if (!ownLink) {
      var $badge = $('span.badge', $link);
      if ($badge.length === 1) {
        // don't update counts in category badge
        if ($link.closest('.badge-category').length === 0) {
          // nor in oneboxes (except when we force it)
          if ($link.closest(".onebox-result").length === 0 || $link.hasClass("track-link")) {
            $badge.html(parseInt($badge.html(), 10) + 1);
          }
        }
      }
    }

    // If they right clicked, change the destination href
    if (e.which === 3) {
      var destination = Discourse.SiteSettings.track_external_right_clicks ? trackingUrl : href;
      $link.attr('href', destination);
      e.preventDefault();
      return true;
    }

    function trackClick(sync) {
      Discourse.ajax("/clicks/track", {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          async: !sync,
          timeout: (sync) ? ACCEPTABLE_BLOCKING_MS : $.ajaxSetup().timeout,
          redirect: false
        },
        dataType: 'html'
      });
    }

    // if they want to open in a new tab, do an AJAX request
    if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) {
      trackClick(true);
      return true;
    }

    e.preventDefault();

    // If we're on the same site, use the router and track via AJAX
    if (Discourse.URL.isInternal(href) && !$link.hasClass('attachment')) {
      trackClick(false);
      Discourse.URL.routeTo(href);
      return false;
    }

    // Otherwise, use a custom URL with a redirect
    if (Discourse.User.currentProp('external_links_in_new_tab')) {
      var win = window.open(trackingUrl, '_blank');
      win.focus();
    } else {
      Discourse.URL.redirectTo(trackingUrl);
    }

    return false;
  }
};
