import ReviewableItemBase from "discourse/lib/reviewable-items/base";

import FlaggedPost from "discourse/lib/reviewable-items/flagged-post";
import QueuedPost from "discourse/lib/reviewable-items/queued-post";
import ReviewableUser from "discourse/lib/reviewable-items/user";

const CLASS_FOR_TYPE = {
  ReviewableFlaggedPost: FlaggedPost,
  ReviewableQueuedPost: QueuedPost,
  ReviewableUser,
};

export function getRenderDirector(
  type,
  reviewable,
  currentUser,
  siteSettings,
  site
) {
  const klass = CLASS_FOR_TYPE[type] || ReviewableItemBase;
  return new klass({ reviewable, currentUser, siteSettings, site });
}
