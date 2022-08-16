import ReviewableTypeBase from "discourse/lib/reviewable-types/base";

import FlaggedPost from "discourse/lib/reviewable-types/flagged-post";
import QueuedPost from "discourse/lib/reviewable-types/queued-post";
import ReviewableUser from "discourse/lib/reviewable-types/user";

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
  const klass = CLASS_FOR_TYPE[type] || ReviewableTypeBase;
  return new klass({ reviewable, currentUser, siteSettings, site });
}
