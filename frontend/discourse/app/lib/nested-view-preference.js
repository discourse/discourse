import { get } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { headerOffset } from "discourse/lib/offset-calculator";
import { userPath } from "discourse/lib/url";

const ANON_KEY = "prefer_flat_replies";

/**
 * Whether the viewer prefers flat replies in nested topics. Anonymous viewers
 * keep the choice in local storage.
 */
export function prefersFlatReplies(currentUser, keyValueStore) {
  if (currentUser) {
    return !!get(currentUser, "user_option.prefer_flat_replies");
  }
  return keyValueStore.get(ANON_KEY) === "true";
}

function saveFlatRepliesPreference(user, preferFlat) {
  return ajax(userPath(`${user.username_lower}.json`), {
    type: "PUT",
    data: { prefer_flat_replies: preferFlat },
  });
}

/**
 * Carries a flat preference chosen while anonymous over to the account once
 * the viewer logs in.
 */
export async function adoptAnonymousFlatRepliesPreference(
  currentUser,
  keyValueStore
) {
  if (!currentUser || keyValueStore.get(ANON_KEY) !== "true") {
    return;
  }

  if (!get(currentUser, "user_option.prefer_flat_replies")) {
    currentUser.set("user_option.prefer_flat_replies", true);
    await saveFlatRepliesPreference(currentUser, true);
  }

  keyValueStore.remove(ANON_KEY);
}

function currentPostNumber(router, topic) {
  let viewportTop = headerOffset();
  if (topic.rendersNested) {
    const controls = document.querySelector(
      ".nested-view:not(.nested-context-view) > .nested-view__controls, .nested-context-view__banner"
    );
    const rect = controls?.getBoundingClientRect();
    if (rect && rect.top <= viewportTop && rect.bottom > viewportTop) {
      viewportTop = rect.bottom;
    }
  }

  // A single thread shows the first post only as context above the thread.
  const selector = topic.rendersNested
    ? ".nested-view:not(.nested-context-view) [data-post-number], .nested-context-view [data-post-number]:not(.nested-view__op-article)"
    : ".topic-post[data-post-number]";
  const visiblePost = [...document.querySelectorAll(selector)].find(
    (element) => {
      const rect = element.getBoundingClientRect();
      return (
        rect.width > 0 &&
        rect.height > 0 &&
        rect.bottom > viewportTop &&
        rect.top < window.innerHeight
      );
    }
  );

  if (visiblePost) {
    return Number(visiblePost.dataset.postNumber);
  }

  if (!topic.rendersNested) {
    return topic.currentPost;
  }
  if (router.currentRoute?.name === "topic.fromParamsNear") {
    return Number(router.currentRoute.params.nearPost);
  }
}

/**
 * Applies a change that flips the topic between nested and flat, then re-enters
 * the topic route at the visible post. A same-topic URL change would otherwise
 * be handled in place and skip the view setup.
 */
export async function switchTopicView(router, topic, applyChange) {
  const postNumber = currentPostNumber(router, topic);
  const targetsPost = Number.isInteger(postNumber) && postNumber > 1;
  const current = router.currentRoute;

  await applyChange();

  const isCurrentRoute = targetsPost
    ? current?.name === "topic.fromParamsNear" &&
      Number(current.params.nearPost) === postNumber
    : current?.name === "topic.fromParams";

  // Not returned: a superseding query param change aborts this transition,
  // which isn't a failure.
  if (isCurrentRoute) {
    router.refresh();
    return;
  }

  let path = `/t/${topic.slug}/${topic.id}`;
  if (targetsPost) {
    path += `/${postNumber}`;
  }
  router.replaceWith(path);
}

export async function toggleFlatRepliesPreference({
  currentUser,
  keyValueStore,
  router,
  topic,
}) {
  const preferFlat = topic.rendersNested;

  try {
    await switchTopicView(router, topic, async () => {
      if (!currentUser) {
        if (preferFlat) {
          keyValueStore.set({ key: ANON_KEY, value: "true" });
        } else {
          keyValueStore.remove(ANON_KEY);
        }
        // Local storage isn't tracked.
        topic.notifyPropertyChange("rendersNested");
        return;
      }

      // Saved first so the view doesn't switch while the request is in flight.
      await saveFlatRepliesPreference(currentUser, preferFlat);
      currentUser.set("user_option.prefer_flat_replies", preferFlat);
    });
  } catch (e) {
    popupAjaxError(e);
  }
}
