import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { dasherize, underscore } from "@ember/string";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import RestModel, { type RestPayload } from "discourse/models/rest";
import type ReviewableHistory from "discourse/models/reviewable-history";
import type { default as Topic, TopicBasicUser } from "discourse/models/topic";
import type User from "discourse/models/user";
import I18n, { i18n } from "discourse-i18n";
import Category from "./category.ts";

export const PENDING = 0 as const;
export const APPROVED = 1 as const;
export const REJECTED = 2 as const;
export const IGNORED = 3 as const;
export const DELETED = 4 as const;

/** Whitelisted core payload keys; extensions augment this interface. */
export interface ReviewablePayload {
  raw?: string;
  title?: string;
  archetype?: string;
  category?: number | null;
  visible?: boolean;
  is_warning?: boolean;
  first_post_checks?: boolean;
  featured_link?: string | null;
  is_poll?: boolean;
  typing_duration_msecs?: number;
  composer_open_duration_msecs?: number;
  tags?: string[] | null;
  via_email?: boolean;
  raw_email?: string | null;
  username?: string;
  email?: string | null;
  name?: string | null;
  bio?: string | null;
  website?: string | null;
  avatar_url?: string | null;
  scrubbed_by?: string;
  scrubbed_reason?: string | null;
  scrubbed_at?: string;
  [key: string]: unknown;
}

/** Histories include synthetic claim events without a model id or status. */
export type ReviewableHistoryEntry =
  | ReviewableHistory
  | {
      reviewable_history_type: number;
      created_at: string;
      created_by: User;
    };

export interface ReviewableScore {
  id: number;
  score: number;
  agree_stats: { agreed: number; disagreed: number; ignored: number };
  reason?: string;
  reason_type: string | null;
  reason_data: string[] | null;
  created_at: string;
  reviewed_at: string | null;
  status: number;
  user: User | null;
  user_id?: number;
  score_type: {
    id: number;
    title: string;
    type: string;
    icon: string;
    reviewable_priority?: number;
  } | null;
  score_type_id?: number;
  reviewed_by: User | null;
  reviewed_by_id?: number | null;
  reviewable_conversation?: {
    id: number;
    permalink: string;
    has_more: boolean;
    conversation_posts: {
      id: number;
      excerpt: string;
      user: User | null;
      user_id?: number;
    }[];
  } | null;
  reviewable_conversation_id?: number | null;
}

export interface ReviewableAction {
  id: string;
  action_name: string;
  icon: string | null;
  button_class: string | null;
  label: string;
  confirm_message?: string;
  confirm_destructive?: boolean;
  description?: string;
  server_action: string | null;
  client_action?: string;
  require_reject_reason?: boolean;
  completed_message: string | null;
  penalty_effect?: string;
}

export interface ReviewableBundledAction {
  id: string;
  icon?: string;
  label?: string;
  secondary?: boolean;
  actions: ReviewableAction[];
  action_ids?: string[];
}

export interface ReviewableClaim {
  /** Only server claims carry an id; MessageBus claims are plain objects. */
  id?: number;
  automatic: boolean;
  user: User | null;
  user_id?: number;
}

export interface ReviewableNote {
  id: number;
  content: string;
  cooked: string;
  created_at: string;
  updated_at: string;
  /** Embedded basic user JSON, not a hydrated User model. */
  user: TopicBasicUser | null;
}

export interface ReviewableAuthorPenalty {
  kind: string;
  forever: boolean;
  expires_at?: string;
  reason?: string;
  applied_at: string;
  automatic: boolean;
  from_this_target: boolean;
  can_lift: boolean;
  applied_by: TopicBasicUser | null;
}

/** Extra moderation fields attached to users in review responses. */
export interface ReviewableUserFields {
  can_delete_all_posts: boolean;
  can_be_deleted: boolean;
  post_count: number;
  topic_count: number;
  ip_address?: string | null;
  email?: string | null;
  custom_fields: Record<string, unknown>;
  flags_agreed: number;
  flags_disagreed: number;
  flags_ignored: number;
  created_at: string;
  trust_level: number;
  silenced_count: number;
  suspended_count: number;
  rejected_posts_count: number;
  silenced_till?: string;
  silence_reason?: string;
  suspended_till?: string;
  suspend_reason?: string;
}

/** Hydrated fields; resolved ids disappear, unresolved ids remain beside null relations. */
export interface ReviewableFields {
  id: number;
  type: string;
  type_source: string;
  status: number;
  score: number;
  version: number;
  created_at: string;
  can_edit: boolean;
  created_from_flag: boolean;
  category_id?: number;
  topic_id?: number | null;
  post_id?: number;
  user_id?: number;
  target_id?: number | null;
  target_type: string | null;
  removed_topic_id?: number | null;
  created_by_id?: number;
  created_by: User | null;
  target_created_by_id?: number | null;
  target_created_by?: (User & ReviewableUserFields) | null;
  target_deleted_by_id?: number;
  target_deleted_by?: User | null;
  topic?: Topic | null;
  claimed_by_id?: number | null;
  claimed_by?: ReviewableClaim | null;
  target?: RestModel | null;
  post?: RestModel | null;
  user?: User | null;
  target_url?: string;
  topic_url?: string;
  target_created_at?: string | null;
  target_deleted_at?: string;
  target_created_by_trust_level: number | null;
  raw?: string;
  cooked?: string | null;
  fancy_title?: string | null;
  deleted_at?: string;
  blank_post?: boolean;
  post_updated_at?: string | null;
  post_version?: number | null;
  payload?: ReviewablePayload | null;
  author_penalties: ReviewableAuthorPenalty[];
  bundled_actions: ReviewableBundledAction[];
  bundled_action_ids?: string[];
  editable_fields: { id: string; type: string }[];
  reviewable_histories: ReviewableHistoryEntry[];
  reviewable_history_ids?: number[];
  reviewable_scores: ReviewableScore[];
  reviewable_score_ids?: number[];
  reviewable_note_ids?: number[];
  topic_tags?: { id: number; name: string; slug: string }[];
  dsa_classification?: { statement_ids: number[] };
  last_performing_username?: string | null;
  reply_count?: number;
  reply_to_post_number?: number;
  link_admin?: boolean;
  user_fields?: Record<string, string | string[]>;
  reject_reason?: string | null;
  /** Embedded JSON, unlike the side-loaded target_created_by model. */
  target_user?: TopicBasicUser & ReviewableUserFields;
  rejectReason?: string;
  sendEmail?: boolean;
}

/** Store input uses side-loaded ids; the instance interface describes hydrated records. */
export type ReviewableWireFields = Omit<
  ReviewableFields,
  | "created_by"
  | "target_created_by"
  | "target_deleted_by"
  | "topic"
  | "claimed_by"
  | "target"
  | "post"
  | "user"
  | "reviewable_histories"
  | "reviewable_scores"
  | "bundled_actions"
> & {
  created_by_id: number;
  reviewable_history_ids: number[];
  reviewable_score_ids: number[];
  bundled_action_ids: string[];
};

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Reviewable extends ReviewableFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Reviewable extends RestModel {
  static override munge(json: RestPayload) {
    // ensure we are not overriding category computed property
    delete json.category;
    return json;
  }

  @tracked author_penalties!: ReviewableFields["author_penalties"];
  @tracked blank_post?: ReviewableFields["blank_post"];
  @tracked bundled_actions!: ReviewableFields["bundled_actions"];
  @tracked can_edit!: ReviewableFields["can_edit"];
  @tracked category_id?: ReviewableFields["category_id"];
  @tracked claimed_by?: ReviewableFields["claimed_by"];
  @tracked cooked?: ReviewableFields["cooked"];
  @tracked created_at!: ReviewableFields["created_at"];
  @tracked created_by!: ReviewableFields["created_by"];
  @tracked created_from_flag!: ReviewableFields["created_from_flag"];
  @tracked deleted_at?: ReviewableFields["deleted_at"];
  @tracked dsa_classification?: ReviewableFields["dsa_classification"];
  @tracked editable_fields!: ReviewableFields["editable_fields"];
  @tracked fancy_title?: ReviewableFields["fancy_title"];
  @tracked id!: ReviewableFields["id"];
  @tracked
  last_performing_username?: ReviewableFields["last_performing_username"];
  @tracked payload?: ReviewableFields["payload"];
  @tracked post_id?: ReviewableFields["post_id"];
  @tracked post_updated_at?: ReviewableFields["post_updated_at"];
  @tracked post_version?: ReviewableFields["post_version"];
  @tracked raw?: ReviewableFields["raw"];
  @tracked removed_topic_id?: ReviewableFields["removed_topic_id"];
  @tracked reviewable_histories!: ReviewableFields["reviewable_histories"];
  @tracked reviewable_scores!: ReviewableFields["reviewable_scores"];
  @tracked score!: ReviewableFields["score"];
  @tracked status!: ReviewableFields["status"];
  @tracked target_created_at?: ReviewableFields["target_created_at"];
  @tracked target_created_by?: ReviewableFields["target_created_by"];
  @tracked
  target_created_by_trust_level!: ReviewableFields["target_created_by_trust_level"];
  @tracked target_deleted_at?: ReviewableFields["target_deleted_at"];
  @tracked target_deleted_by?: ReviewableFields["target_deleted_by"];
  @tracked target_id?: ReviewableFields["target_id"];
  @tracked target_type!: ReviewableFields["target_type"];
  @tracked target_url?: ReviewableFields["target_url"];
  @tracked topic?: ReviewableFields["topic"];
  @tracked topic_id?: ReviewableFields["topic_id"];
  @tracked topic_tags?: ReviewableFields["topic_tags"];
  @tracked topic_url?: ReviewableFields["topic_url"];
  @tracked type!: ReviewableFields["type"];
  @tracked type_source!: ReviewableFields["type_source"];
  @tracked version!: ReviewableFields["version"];
  @autoTrackedArray reviewable_notes: ReviewableNote[] = [];

  @computed("type", "topic")
  get resolvedType() {
    // Display "Queued Topic" if the post will create a topic
    if (this.type === "ReviewableQueuedPost" && !this.topic) {
      return "ReviewableQueuedTopic";
    }

    return this.type;
  }

  @computed("resolvedType")
  get humanType(): string {
    return i18n(`review.types.${underscore(this.resolvedType)}.title`, {
      defaultValue: "",
    });
  }

  @computed("humanType")
  get humanTypeCssClass() {
    return "-" + dasherize(this.humanType);
  }

  @computed("resolvedType")
  get humanNoun(): string {
    return i18n(`review.types.${underscore(this.resolvedType)}.noun`, {
      defaultValue: "reviewable",
    });
  }

  @computed("humanNoun")
  /** Requires scores to be loaded, including each referenced score type. */
  get flaggedReviewableContextQuestion(): string {
    // TODO(typescript-pending): uniqueItemsFromArray loses its element type; remove this assertion when generic.
    const uniqueReviewableScores = uniqueItemsFromArray(
      this.reviewable_scores,
      "score_type.type"
    ) as ReviewableScore[];

    if (uniqueReviewableScores.length === 1) {
      if (uniqueReviewableScores[0].score_type!.type === "notify_moderators") {
        return i18n("review.context_question.something_else_wrong", {
          reviewable_type: this.humanNoun,
        });
      }
    }

    const listOfQuestions = I18n.listJoiner(
      uniqueItemsFromArray(
        uniqueReviewableScores.map((score) =>
          score.score_type!.title.toLowerCase()
        )
      ) as string[],
      i18n("review.context_question.delimiter")
    );

    return i18n("review.context_question.is_this_post", {
      reviewable_human_score_types: listOfQuestions,
      reviewable_type: this.humanNoun,
    });
  }

  @computed("resolvedType", "reviewable_scores", "status")
  get userReviewableContextQuestion(): string | null {
    if (this.resolvedType === "ReviewableUser") {
      // in this case the only remaining action is "scrub record" so the question shouldn't show
      if (this.status !== PENDING) {
        return null;
      }
      const isSuspectUser = this.reviewable_scores?.some(
        (score) => score.reason_type === "suspect_user"
      );
      if (isSuspectUser) {
        return i18n("review.context_question.suspect_user");
      }
      return i18n("review.context_question.approve_user");
    }
    if (this.resolvedType === "ReviewableQueuedPost") {
      return i18n("review.context_question.approve_post");
    }
    if (this.resolvedType === "ReviewableQueuedTopic") {
      return i18n("review.context_question.approve_topic");
    }
    if (this.resolvedType === "ReviewablePost") {
      return i18n("review.context_question.approve_post");
    }
    return null;
  }

  @computed("category_id")
  get category() {
    return Category.findById(this.category_id);
  }

  /** Keeps the override assignable to RestModel; resolves without a save-result envelope. */
  override update(this: never, ...args: never[]): never;
  override update(updates: object): globalThis.Promise<void>;
  override update(updates: object): globalThis.Promise<void> {
    // If no changes, do nothing
    if (Object.keys(updates).length === 0) {
      return Promise.resolve();
    }

    // eslint-disable-next-line prefer-const
    let adapter = this.store.adapterFor("reviewable");
    // TODO(typescript-pending): ajax has no endpoint response types; remove the callback annotation when generic.
    return ajax(
      `/review/${this.id}?version=${this.version}`,
      adapter.getPayload("PUT", { reviewable: updates })
    ).then((updated: Partial<ReviewableFields>) => {
      updated.payload = Object.assign(
        {},
        this.payload || {},
        updated.payload || {}
      );

      this.setProperties(updated);
    });
  }
}
