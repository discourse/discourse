import { tracked } from "@glimmer/tracking";
import { applyModelTransformations } from "discourse/lib/model-transformers";
import RestModel, { type RestModelAttrs } from "discourse/models/rest";

/** Known core packet keys are optional; other producers can add arbitrary data. */
export interface NotificationData {
  display_username?: string;
  display_name?: string | null;
  topic_title?: string;
  original_post_id?: number;
  original_post_type?: number;
  original_user_id?: number;
  original_username?: string;
  original_name?: string | null;
  revision_number?: number | null;
  group_id?: number;
  group_name?: string;
  reply_to_post_number?: number;
  consolidated_count?: number;
  previous_notification_id?: number;
  username?: string;
  username2?: string;
  name?: string | null;
  name2?: string | null;
  count?: number;
  badge_id?: number;
  badge_name?: string;
  badge_slug?: string;
  badge_title?: boolean;
  inbox_count?: number;
  message?: string;
  title?: string;
  post_url?: string;
  bookmarkable_url?: string;
  bookmark_name?: string | null;
  bookmark_id?: number;
  bookmarkable_type?: string;
  bookmarkable_id?: number;
  reviewable_id?: number;
  reviewable_note_id?: number;
  upcoming_change_names?: string[];
  upcoming_change_humanized_names?: string[];
  upcoming_change_name?: string;
  upcoming_change_humanized_name?: string;
  [key: string]: unknown;
}

export interface NotificationFields {
  id: number;
  user_id: number;
  notification_type: number;
  high_priority: boolean;
  created_at: string;
  topic_id: number | null;
  post_number: number | null;
  slug: string | null;
  data: NotificationData;
  fancy_title?: string;
  fancy_title_localized?: boolean;
  locale?: string | null;
  external_id?: string | null;
  is_warning?: boolean;
  acting_user_avatar_template?: string;
  acting_user_name?: string | null;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Notification extends NotificationFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Notification extends RestModel {
  static async applyTransformations(notifications: Notification[]) {
    await applyModelTransformations("notification", notifications);
  }

  static async initializeNotifications(
    rawList: RestModelAttrs<Notification>[]
  ) {
    const notifications = rawList.map((n) => this.create(n));
    await this.applyTransformations(notifications);
    return notifications;
  }

  /** Assigned by create; the bare tracked field starts undefined. */
  @tracked read!: boolean;
}
