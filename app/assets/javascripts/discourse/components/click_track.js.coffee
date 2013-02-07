# We use this object to keep track of click counts.
window.Discourse.ClickTrack =

  # Pass the event of the click here and we'll do the magic!
  trackClick: (e) ->

    $a = $(e.currentTarget)

    e.preventDefault()

    # We don't track clicks on quote back buttons
    return true if $a.hasClass('back') or $a.hasClass('quote-other-topic')

    # Remove the href, put it as a data attribute
    unless $a.data('href')
      $a.addClass('no-href')
      $a.data('href', $a.attr('href'))
      $a.attr('href', null)

      # Don't route to this URL
      $a.data('auto-route', true)

    href = $a.data('href')
    $article = $a.closest('article')
    postId = $article.data('post-id')
    topicId = $('#topic').data('topic-id')
    userId = $a.data('user-id')
    userId = $article.data('user-id') unless userId

    ownLink = userId and (userId is Discourse.get('currentUser.id'))

    # Build a Redirect URL
    trackingUrl = "/clicks/track?url=" + encodeURIComponent(href)
    trackingUrl += "&post_id=" + encodeURI(postId) if postId and (not $a.data('ignore-post-id'))
    trackingUrl += "&topic_id=" + encodeURI(topicId) if topicId

    # Update badge clicks unless it's our own
    unless ownLink
      $badge = $('span.badge', $a)
      if $badge.length == 1
        count = parseInt($badge.html())
        $badge.html(count + 1)

    # If they right clicked, change the destination href
    if e.which is 3
      destination = if Discourse.SiteSettings.track_external_right_clicks then trackingUrl else href
      $a.attr('href', destination)
      return true

    # if they want to open in a new tab, do an AJAX request
    if (e.metaKey || e.ctrlKey || e.which is 2)
      $.get "/clicks/track", url: href, post_id: postId, topic_id: topicId, redirect: false
      window.open(href, '_blank')
      return false

    # If we're on the same site, use the router and track via AJAX
    if href.indexOf(window.location.origin) == 0
      $.get "/clicks/track", url: href, post_id: postId, topic_id: topicId, redirect: false
      Discourse.routeTo(href)
      return false

    # Otherwise, use a custom URL with a redirect
    window.location = trackingUrl
    false
