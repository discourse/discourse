import { get } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
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
    await ajax(userPath(`${currentUser.username_lower}.json`), {
      type: "PUT",
      data: { prefer_flat_replies: true },
    });
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
  let visiblePost;
  let closestTop = Infinity;

  for (const element of document.querySelectorAll(selector)) {
    const rect = element.getBoundingClientRect();
    const postNumber = Number(element.dataset.postNumber);
    if (
      !Number.isInteger(postNumber) ||
      postNumber < 1 ||
      rect.width === 0 ||
      rect.height === 0 ||
      rect.bottom <= viewportTop ||
      rect.top >= window.innerHeight
    ) {
      continue;
    }

    const top = Math.max(rect.top, viewportTop);
    if (top < closestTop) {
      closestTop = top;
      visiblePost = postNumber;
    }
  }

  if (visiblePost) {
    return visiblePost;
  }

  if (!topic.rendersNested) {
    return topic.currentPost;
  }
  if (router.currentRoute?.name === "topic.fromParamsNear") {
    return Number(router.currentRoute.params.nearPost);
  }
}

/**
 * Applies a change that flips the topic between the nested and flat views,
 * then re-runs the topic route so it can tear down one view and set up the
 * other, staying on the post the user was reading. Same-topic URL changes are
 * otherwise handled in place, which skips that setup.
 */
export function switchTopicView(
  router,
  topic,
  applyChange,
  postNumber = currentPostNumber(router, topic)
) {
  const targetsPost = Number.isInteger(postNumber) && postNumber > 1;
  const current = router.currentRoute;

  applyChange();

  const isCurrentRoute = targetsPost
    ? current?.name === "topic.fromParamsNear" &&
      Number(current.params.nearPost) === postNumber
    : current?.name === "topic.fromParams";

  // Not returned: a query param change can supersede the transition, and the
  // aborted one would surface as an error even though the switch completes.
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
  const postNumber = currentPostNumber(router, topic);

  if (!currentUser) {
    switchTopicView(
      router,
      topic,
      () => {
        if (preferFlat) {
          keyValueStore.set({ key: ANON_KEY, value: "true" });
        } else {
          keyValueStore.remove(ANON_KEY);
        }
        // Local storage isn't tracked.
        topic.notifyPropertyChange("rendersNested");
      },
      postNumber
    );
    return;
  }

  // Saved before updating the user so the view doesn't switch to stale
  // content while the request is in flight.
  await ajax(userPath(`${currentUser.username_lower}.json`), {
    type: "PUT",
    data: { prefer_flat_replies: preferFlat },
  });

  switchTopicView(
    router,
    topic,
    () => currentUser.set("user_option.prefer_flat_replies", preferFlat),
    postNumber
  );
}
