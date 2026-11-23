import type Reviewable from "discourse/models/reviewable";

declare const reviewable: Reviewable;
reviewable.ai_suggested_action_name satisfies string | undefined;
reviewable.ai_suggested_action_name = "post-agree_and_hide";
reviewable.ai_suggested_action_name = undefined;
// @ts-expect-error Suggestions identify actions by name.
reviewable.ai_suggested_action_name = 1;
