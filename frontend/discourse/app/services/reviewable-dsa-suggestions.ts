import Service from "@ember/service";

/** A suggested option ID with its attribution, or guidance for manual selection. */
export type ReviewableDsaFieldOutcome =
  | { value: string; label: string; errorLabel?: never }
  | { errorLabel: string; value?: never; label?: never };

export interface ReviewableDsaSuggestions {
  /** Ignored when the site's only community rule is already selected. */
  communityRule?: ReviewableDsaFieldOutcome;
  /** An outcome for the DSA category dropdown. */
  category?: ReviewableDsaFieldOutcome;
}

export interface ReviewableDsaSuggestionProvider {
  /** Shown below eligible fields and announced once while the request is pending. */
  loadingLabel: string;
  /** Called once when a moderation form with DSA classification opens for this reviewable. */
  suggest(reviewableId: number): Promise<ReviewableDsaSuggestions>;
}

export default class ReviewableDsaSuggestionsService extends Service {
  provider?: ReviewableDsaSuggestionProvider;
}
