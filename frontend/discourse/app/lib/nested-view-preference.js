import { get } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
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
export function switchTopicView(router, topic, applyChange) {
  const postNumber = currentPostNumber(router, topic);
  const targetsPost = Number.isInteger(postNumber) && postNumber > 1;
  const current = router.currentRoute;

  applyChange();

  const isCurrentRoute = targetsPost
    ? current?.name === "topic.fromParamsNear" &&
      Number(current.params.nearPost) === postNumber
    : current?.name === "topic.fromParams";

  if (isCurrentRoute) {
    return router.refresh();
  }

  let path = `/t/${topic.slug}/${topic.id}`;
  if (targetsPost) {
    path += `/${postNumber}`;
  }
  return router.replaceWith(path);
}

export async function toggleFlatRepliesPreference({
  currentUser,
  keyValueStore,
  router,
  topic,
}) {
  const preferFlat = topic.rendersNested;

  if (!currentUser) {
    return switchTopicView(router, topic, () => {
      if (preferFlat) {
        keyValueStore.set({ key: ANON_KEY, value: "true" });
      } else {
        keyValueStore.remove(ANON_KEY);
      }
      // Local storage isn't tracked.
      topic.notifyPropertyChange("rendersNested");
    });
  }

  // Saved before updating the user so the view doesn't switch to stale
  // content while the request is in flight.
  await ajax(userPath(`${currentUser.username_lower}.json`), {
    type: "PUT",
    data: { prefer_flat_replies: preferFlat },
  });

  return switchTopicView(router, topic, () =>
    currentUser.set("user_option.prefer_flat_replies", preferFlat)
  );
}
