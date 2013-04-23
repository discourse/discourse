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

    e.preventDefault();

    // We don't track clicks on quote back buttons
    if ($link.hasClass('back') || $link.hasClass('quote-other-topic')) return true;

    // Remove the href, put it as a data attribute
    if (!$link.data('href')) {
      $link.addClass('no-href');
      $link.data('href', $link.attr('href'));
      $link.attr('href', null);
      // Don't route to this URL
      $link.data('auto-route', true);
    }

    var href = $link.data('href'),
        $article = $link.closest('article'),
        postId = $article.data('post-id'),
        topicId = $('#topic').data('topic-id'),
        userId = $link.data('user-id');

    if (!userId) userId = $article.data('user-id');
    var ownLink = userId && (userId === Discourse.get('currentUser.id'));

    // Build a Redirect URL
    var trackingUrl = Discourse.getURL("/clicks/track?url=" + encodeURIComponent(href));
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
        // don't update counts in oneboxes (except when we force it)
        if ($link.closest(".onebox-result").length === 0 || $link.hasClass("track-link")) {
          $badge.html(parseInt($badge.html(), 10) + 1);
        }
      }
    }

    // If they right clicked, change the destination href
    if (e.which === 3) {
      var destination = Discourse.SiteSettings.track_external_right_clicks ? trackingUrl : href;
      $link.attr('href', destination);
      return true;
    }

    // if they want to open in a new tab, do an AJAX request
    if (e.metaKey || e.ctrlKey || e.which === 2) {
      Discourse.ajax(Discourse.getURL("/clicks/track"), {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        }
      });
      window.open(href, '_blank');
      return false;
    }

    // If we're on the same site, use the router and track via AJAX
    if (href.indexOf(Discourse.URL.origin()) === 0) {
      Discourse.ajax(Discourse.getURL("/clicks/track"), {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        }
      });
      Discourse.URL.routeTo(href);
      return false;
    }

    // Otherwise, use a custom URL with a redirect
    if (Discourse.get('currentUser.external_links_in_new_tab')) {
      var win = window.open(trackingUrl, '_blank');
      win.focus();
    } else {
      Discourse.URL.redirectTo(trackingUrl);
    }

    return false;
  }
};


