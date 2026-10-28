import { tracked } from "@glimmer/tracking";
import RestModel from "discourse/models/rest";

/** Basic serializer shape, also used as the fallback for extension types. */
export interface UserMenuReviewableFields {
  id: number;
  type: string;
  created_at: string;
  flagger_username: string | null;
  /** Present only on the corresponding core basic serializer. */
  post_number?: number;
  topic_fancy_title?: string;
  is_new_topic?: boolean;
  payload_title?: string;
  username?: string;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface UserMenuReviewable extends UserMenuReviewableFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class UserMenuReviewable extends RestModel {
  @tracked pending!: boolean;
}
