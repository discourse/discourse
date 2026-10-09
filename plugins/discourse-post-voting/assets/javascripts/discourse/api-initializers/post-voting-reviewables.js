import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.registerReviewableComponent(
    "ReviewablePostVotingComment",
    async () =>
      (await import("../components/reviewable/post-voting-comment")).default
  );
});
