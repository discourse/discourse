
/* We use this object to keep track of click counts.
*/


(function() {

  window.Discourse.ClickTrack = {
    /* Pass the event of the click here and we'll do the magic!
    */

    trackClick: function(e) {
      var $a, $article, $badge, count, destination, href, ownLink, postId, topicId, trackingUrl, userId;
      $a = jQuery(e.currentTarget);
      if ($a.hasClass('lightbox')) {
        return;
      }
      e.preventDefault();
      /* We don't track clicks on quote back buttons
      */

      if ($a.hasClass('back') || $a.hasClass('quote-other-topic')) {
        return true;
      }
      /* Remove the href, put it as a data attribute
      */

      if (!$a.data('href')) {
        $a.addClass('no-href');
        $a.data('href', $a.attr('href'));
        $a.attr('href', null);
        /* Don't route to this URL
        */

        $a.data('auto-route', true);
      }
      href = $a.data('href');
      $article = $a.closest('article');
      postId = $article.data('post-id');
      topicId = jQuery('#topic').data('topic-id');
      userId = $a.data('user-id');
      if (!userId) {
        userId = $article.data('user-id');
      }
      ownLink = userId && (userId === Discourse.get('currentUser.id'));
      /* Build a Redirect URL
      */

      trackingUrl = "/clicks/track?url=" + encodeURIComponent(href);
      if (postId && (!$a.data('ignore-post-id'))) {
        trackingUrl += "&post_id=" + encodeURI(postId);
      }
      if (topicId) {
        trackingUrl += "&topic_id=" + encodeURI(topicId);
      }
      /* Update badge clicks unless it's our own
      */

      if (!ownLink) {
        $badge = jQuery('span.badge', $a);
        if ($badge.length === 1) {
          count = parseInt($badge.html(), 10);
          $badge.html(count + 1);
        }
      }
      /* If they right clicked, change the destination href
      */

      if (e.which === 3) {
        destination = Discourse.SiteSettings.track_external_right_clicks ? trackingUrl : href;
        $a.attr('href', destination);
        return true;
      }
      /* if they want to open in a new tab, do an AJAX request
      */

      if (e.metaKey || e.ctrlKey || e.which === 2) {
        jQuery.get("/clicks/track", {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        });
        window.open(href, '_blank');
        return false;
      }
      /* If we're on the same site, use the router and track via AJAX
      */

      if (href.indexOf(window.location.origin) === 0) {
        jQuery.get("/clicks/track", {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        });
        Discourse.routeTo(href);
        return false;
      }
      /* Otherwise, use a custom URL with a redirect
      */

      window.location = trackingUrl;
      return false;
    }
  };

}).call(this);
