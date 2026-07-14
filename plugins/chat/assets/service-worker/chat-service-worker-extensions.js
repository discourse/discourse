// Registers a "chat-reply" handler for the Web Notifications API "Reply"
// quick-action button on chat push notifications. Invoked by the core
// service worker (app/views/static/service-worker.js.erb) when the user
// types a reply and submits the action button on the notification.
//
// If the reply is a single emoji grapheme (typical of smartwatch quick
// reply chips), it is sent to the chat reaction endpoint instead of
// posting a one-character message in the channel. Reaction failures
// transparently fall back to a normal message post so a user's tap is
// never lost.
//
// The matching action button and its action_data payload are produced
// server-side by Chat::Notifier.push_notification_reply_action.

// Matches a single base pictographic codepoint, optionally followed by
// a variation selector (U+FE0F) or skin tone (U+1F3FB..U+1F3FF), plus
// zero or more ZWJ-joined (U+200D) parts. Used as a fallback when
// Intl.Segmenter is unavailable.
const SINGLE_EMOJI_FALLBACK_RE =
  /^(?:\p{Extended_Pictographic}(?:\u{FE0F}|[\u{1F3FB}-\u{1F3FF}])?)(?:\u{200D}\p{Extended_Pictographic}(?:\u{FE0F}|[\u{1F3FB}-\u{1F3FF}])?)*$/u;

function isSingleEmoji(text) {
  if (!text) {
    return false;
  }

  if (typeof Intl !== "undefined" && Intl.Segmenter) {
    const iter = new Intl.Segmenter(undefined, {
      granularity: "grapheme",
    })
      .segment(text)
      [Symbol.iterator]();
    const first = iter.next();
    if (first.done || !iter.next().done) {
      return false;
    }
    return /\p{Extended_Pictographic}/u.test(first.value.segment);
  }

  return SINGLE_EMOJI_FALLBACK_RE.test(text);
}

function fetchCsrfToken(baseUrl) {
  return fetch(baseUrl + "/session/csrf", {
    credentials: "include",
    headers: { Accept: "application/json" },
  })
    .then(function (response) {
      if (!response.ok) {
        throw new Error("CSRF fetch failed: " + response.status);
      }
      return response.json();
    })
    .then(function (json) {
      return json.csrf;
    });
}

function postChatMessage({ baseUrl, csrf, channelId, threadId, message }) {
  const body = new URLSearchParams();
  body.set("message", message);
  if (threadId) {
    body.set("thread_id", String(threadId));
  }

  return fetch(baseUrl + "/chat/" + encodeURIComponent(channelId), {
    credentials: "include",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
      "X-CSRF-Token": csrf,
      Accept: "application/json",
    },
    body: body.toString(),
    method: "POST",
  }).then(function (response) {
    if (!response.ok) {
      throw new Error("Chat reply POST failed: " + response.status);
    }
    return response;
  });
}

function reactToChatMessage({ baseUrl, csrf, channelId, messageId, emoji }) {
  const body = new URLSearchParams();
  body.set("react_action", "add");
  body.set("emoji", emoji);

  return fetch(
    baseUrl +
      "/chat/" +
      encodeURIComponent(channelId) +
      "/react/" +
      encodeURIComponent(messageId),
    {
      credentials: "include",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded; charset=UTF-8",
        "X-CSRF-Token": csrf,
        Accept: "application/json",
      },
      body: body.toString(),
      method: "PUT",
    }
  ).then(function (response) {
    if (!response.ok) {
      throw new Error("Chat reaction PUT failed: " + response.status);
    }
    return response;
  });
}

self.registerNotificationActionHandler("chat-reply", function (event) {
  const data = event.notification.data || {};
  const actionData = data.actionData || {};
  const baseUrl = data.baseUrl || "";
  const fallbackUrl = data.url || "";
  const reply = (event.reply || "").trim();

  function openFallback() {
    if (!fallbackUrl || !self.clients || !self.clients.openWindow) {
      return Promise.resolve();
    }
    return self.clients.openWindow(baseUrl + fallbackUrl);
  }

  if (!actionData.channel_id || !reply) {
    return openFallback();
  }

  const tryReact =
    actionData.message_id && isSingleEmoji(reply)
      ? function (csrf) {
          return reactToChatMessage({
            baseUrl,
            csrf,
            channelId: actionData.channel_id,
            messageId: actionData.message_id,
            emoji: reply,
          }).catch(function (err) {
            // eslint-disable-next-line no-console
            console.warn("Chat reaction failed, falling back to message", err);
            return postChatMessage({
              baseUrl,
              csrf,
              channelId: actionData.channel_id,
              threadId: actionData.thread_id,
              message: reply,
            });
          });
        }
      : function (csrf) {
          return postChatMessage({
            baseUrl,
            csrf,
            channelId: actionData.channel_id,
            threadId: actionData.thread_id,
            message: reply,
          });
        };

  return fetchCsrfToken(baseUrl)
    .then(tryReact)
    .catch(function (err) {
      // eslint-disable-next-line no-console
      console.error("Chat quick reply failed", err);
      return openFallback();
    });
});
