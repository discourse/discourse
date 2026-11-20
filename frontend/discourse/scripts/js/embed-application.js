(function () {
  const referer = document.getElementById("data-embedded").dataset.referer;

  function postUp(msg) {
    if (parent) {
      parent.postMessage(msg, referer);
    }
  }

  function clickPostLink(e) {
    let postId = e.target.getAttribute("data-link-to-post");
    if (postId) {
      let postElement = document.getElementById("post-" + postId);
      if (postElement) {
        let rect = postElement.getBoundingClientRect();
        if (rect && rect.top) {
          postUp({ type: "discourse-scroll", top: rect.top });
          e.preventDefault();
          return false;
        }
      }
    }
  }

  // Poll for the topic to be created so we can render comments as soon as
  // possible instead of waiting for the full meta-refresh interval.
  //
  // Use exponential backoff with full jitter so clients landing on the same
  // article don't synchronise their polls (thundering herd on /embed/status).
  // The poll URL is left cacheable so the shared anonymous response cache can
  // serve concurrent polls instead of hitting the database.
  const POLL_MIN_DELAY = 1500;
  const POLL_MAX_DELAY = 10000;

  function pollForTopic() {
    let retryDelay = POLL_MIN_DELAY;

    const scheduleNextPoll = () => {
      const wait = Math.random() * retryDelay;
      retryDelay = Math.min(retryDelay * 2, POLL_MAX_DELAY);
      setTimeout(poll, wait);
    };

    const poll = () => {
      const pollUrl = new URL(window.location.href);
      pollUrl.pathname = pollUrl.pathname.replace(/\/comments$/, "/status");
      fetch(pollUrl, { headers: { Accept: "application/json" } })
        .then((response) => response.json())
        .then((data) => {
          if (data.topic_id) {
            window.location.reload();
            return;
          }
          scheduleNextPoll();
        })
        .catch(scheduleNextPoll);
    };

    scheduleNextPoll();
  }

  window.onload = function () {
    // get state info from data attribute
    let embedState = document.querySelector("[data-embed-state]");
    let state = "unknown";
    let embedId = null;
    if (embedState) {
      state = embedState.getAttribute("data-embed-state");
      embedId = embedState.getAttribute("data-embed-id");
    }

    // Send a post message with our loaded height and state
    postUp({
      type: "discourse-resize",
      height: document["body"].offsetHeight,
      state,
      embedId,
    });

    if (state === "loading") {
      pollForTopic();
    }

    let postLinks = document.querySelectorAll("a[data-link-to-post]"),
      i;

    for (i = 0; i < postLinks.length; i++) {
      postLinks[i].onclick = clickPostLink;
    }

    // Make sure all links in the iframe point to _blank
    let cookedLinks = document.querySelectorAll(".cooked a");
    for (i = 0; i < cookedLinks.length; i++) {
      cookedLinks[i].target = "_blank";
    }

    // Use a # for hashtags since we don't have the JS and icons needed here to render the proper icon.
    let hashtags = document.querySelectorAll(".cooked a.hashtag-cooked");
    for (i = 0; i < hashtags.length; i++) {
      hashtags[i].querySelector(".hashtag-icon-placeholder .d-icon").remove();
      hashtags[i].querySelector(".hashtag-icon-placeholder").innerText = "#";
    }
  };
})();
