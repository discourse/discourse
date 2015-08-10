import DiscourseURL from 'discourse/lib/url';

export default {
  trackClick(e) {
    // cancel click if triggered as part of selection.
    if (Discourse.Utilities.selectedText() !== "") { return false; }

    var $link = $(e.currentTarget);
    if ($link.hasClass('lightbox')) { return true; }

    var href = $link.attr('href') || $link.data('href'),
        $article = $link.closest('article'),
        postId = $article.data('post-id'),
        topicId = $('#topic').data('topic-id'),
        userId = $link.data('user-id');

    if (!href || href.trim().length === 0) { return; }

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
        // don't update counts in category badge nor in oneboxes (except when we force it)
        if ($link.hasClass("track-link") ||
            $link.closest('.badge-category,.onebox-result,.onebox-body').length === 0) {
          var html = $badge.html();
          if (/^\d+$/.test(html)) { $badge.html(parseInt(html, 10) + 1); }
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
    if (e.shiftKey || e.metaKey || e.ctrlKey || e.which === 2) {
      Discourse.ajax("/clicks/track", {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        },
        dataType: 'html'
      });
      return true;
    }

    e.preventDefault();

    // We don't track clicks on quote back buttons
    if ($link.hasClass('back') || $link.hasClass('quote-other-topic')) { return true; }

    // Remove the href, put it as a data attribute
    if (!$link.data('href')) {
      $link.addClass('no-href');
      $link.data('href', $link.attr('href'));
      $link.attr('href', null);
      // Don't route to this URL
      $link.data('auto-route', true);
    }

    // restore href
    setTimeout(() => {
      $link.removeClass('no-href');
      $link.attr('href', $link.data('href'));
      $link.data('href', null);
    }, 50);

    // warn the user if they can't download the file
    if (Discourse.SiteSettings.prevent_anons_from_downloading_files && $link.hasClass("attachment") && !Discourse.User.current()) {
      bootbox.alert(I18n.t("post.errors.attachment_download_requires_login"));
      return false;
    }

    // If we're on the same site, use the router and track via AJAX
    if (DiscourseURL.isInternal(href) && !$link.hasClass('attachment')) {
      Discourse.ajax("/clicks/track", {
        data: {
          url: href,
          post_id: postId,
          topic_id: topicId,
          redirect: false
        },
        dataType: 'html'
      });
      DiscourseURL.routeTo(href);
      return false;
    }

    // Otherwise, use a custom URL with a redirect
    if (Discourse.User.currentProp('external_links_in_new_tab')) {
      var win = window.open(trackingUrl, '_blank');
      win.focus();
    } else {
      DiscourseURL.redirectTo(trackingUrl);
    }

    return false;
  }
};
