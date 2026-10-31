/* eslint-disable ember/no-observers */
/* eslint-disable prefer-const -- Preserve the original bindings in this types-only port. */
import { tracked } from "@glimmer/tracking";
import EmberObject, { computed, get, getProperties, set } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import Evented from "@ember/object/evented";
import { getOwner, setOwner } from "@ember/owner";
import { trackedArray } from "@ember/reactive/collections";
import { cancel, type Timer } from "@ember/runloop";
import { service } from "@ember/service";
import { camelize } from "@ember/string";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import type { MomentInput } from "moment";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import {
  addUniqueValueToArray,
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import {
  AUTO_GROUPS,
  INTERFACE_COLOR_MODES,
  USER_OPTION_COMPOSITION_MODES,
} from "discourse/lib/constants";
import cookie, { removeCookie } from "discourse/lib/cookie";
import deprecated from "discourse/lib/deprecated";
import { isTesting } from "discourse/lib/environment";
import { longDate } from "discourse/lib/formatter";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL, { getURLWithCDN } from "discourse/lib/get-url";
import discourseLater from "discourse/lib/later";
import { NotificationLevels } from "discourse/lib/notification-levels";
import PreloadStore from "discourse/lib/preload-store";
import singleton from "discourse/lib/singleton";
import { emojiUnescape } from "discourse/lib/text";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import {
  applyBehaviorTransformer,
  applyValueTransformer,
} from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import { defaultHomepage, escapeExpression } from "discourse/lib/utilities";
import Badge from "discourse/models/badge";
import Bookmark from "discourse/models/bookmark";
import Category from "discourse/models/category";
import Group, { type GroupFields } from "discourse/models/group";
import RestModel, {
  type RestModelAttrs,
  type RestModelClass,
  type RestModelSaveResult,
  type RestModelStoreAttrs,
  type RestPayload,
} from "discourse/models/rest";
import Site, {
  type SiteSidebarSection,
  type SiteSidebarTag,
  type SiteTopTag,
} from "discourse/models/site";
import type { default as Topic, TopicBasicUser } from "discourse/models/topic";
import UserAction, {
  type UserActionFields,
} from "discourse/models/user-action";
import UserActionStat from "discourse/models/user-action-stat";
import UserBadge from "discourse/models/user-badge";
import UserDraftsStream from "discourse/models/user-drafts-stream";
import UserPostsStream from "discourse/models/user-posts-stream";
import UserStream from "discourse/models/user-stream";
import type AppEventsService from "discourse/services/app-events";
import type NotificationsService from "discourse/services/notifications";
import type StoreService from "discourse/services/store";
import { i18n } from "discourse-i18n";

/** Status supplied by the server; clearing a status assigns null on the user. */
export interface UserStatus {
  description: string;
  emoji: string;
  ends_at: string | null;
  message_bus_last_id?: number;
}

/** Options are partial: current-user and profile serializers expose different subsets. */
export interface UserOption {
  allow_private_messages?: boolean;
  auto_track_topics_after_msecs?: number;
  automatically_translate?: boolean;
  automatically_unpin_topics?: boolean;
  bookmark_auto_delete_preference?: number;
  color_scheme_id?: number | null;
  composition_mode?: number;
  dark_scheme_id?: number | null;
  default_calendar?: string;
  digest_after_minutes?: number | null;
  dynamic_favicon?: boolean;
  email_digests?: boolean | null;
  email_in_reply_to?: boolean;
  email_level?: number;
  email_messages_level?: number;
  email_previous_replies?: number;
  enable_allowed_pm_users?: boolean;
  enable_markdown_monospace_font?: boolean;
  enable_quoting?: boolean;
  enable_smart_lists?: boolean;
  enable_upcoming_change_available_notifications?: boolean;
  external_links_in_new_tab?: boolean;
  hidden_composer_toolbar_buttons?: string[];
  hide_presence?: boolean;
  hide_profile?: boolean;
  hide_profile_and_presence?: boolean;
  homepage_id?: number | null;
  include_tl0_in_digests?: boolean | null;
  interface_color_mode?: number;
  like_notification_frequency?: number;
  likes_notifications_disabled?: boolean;
  mailing_list_mode?: boolean;
  mailing_list_mode_frequency?: number;
  new_topic_duration_minutes?: number;
  notification_level_when_replying?: number;
  notify_on_linked_posts?: boolean;
  oldest_search_log_date?: string | null;
  push_notification_level?: string;
  redirected_to_top?: { reason: string | null; period: string | number } | null;
  seen_popups?: number[] | null;
  send_shortcut?: string;
  should_be_redirected_to_top?: boolean;
  show_original_content?: boolean;
  sidebar_link_to_filtered_list?: boolean;
  sidebar_show_count_of_new_items?: boolean;
  skip_new_user_tips?: boolean;
  text_size?: string;
  text_size_seq?: number;
  theme_ids?: number[];
  theme_key_seq?: number;
  timezone?: string | null;
  title_count_mode?: string;
  treat_as_new_topic_start_date?: string;
  understood_languages?: string[];
  user_id?: number;
  watched_precedence_over_muted?: boolean;
}

/** Visible memberships can be plain current-user entries or hydrated profile groups. */
export interface UserGroup
  extends
    Required<Pick<GroupFields, "id" | "name">>,
    Pick<
      GroupFields,
      | "automatic"
      | "has_messages"
      | "title"
      | "flair_url"
      | "flair_bg_color"
      | "flair_color"
      | "can_admin_group"
      | "is_group_owner"
      | "group_user"
    > {
  owner?: true;
}

/** TODO(typescript-pending): Badge's field forwarders and factories lack declared fields; remove when Badge is typed. */
type UserBadgeModel = Badge & {
  id: number;
  name: string;
  allow_title?: boolean;
  count?: number;
};

/** A user-authorized API key, before or after it is wrapped in an EmberObject. */
export interface UserApiKey {
  id: number;
  application_name: string;
  scopes: string[];
  created_at: string;
  last_used_at: string;
  expires_at: string | null;
  revoked?: boolean;
}

type WrappedUserApiKey = EmberObject &
  UserApiKey & {
    revoke(): void;
    undoRevoke(): void;
  };

/** Core serializer and client-assigned fields. Plugins augment this interface. */
export interface UserFields {
  /** Username-only instances are hydrated by findDetails before identity-dependent use. */
  id: number;
  /** Username-only instances are hydrated by findDetails before identity-dependent use. */
  username: string;
  avatar_template: string;
  added_at?: string;
  admin?: boolean;
  all_unread_notifications_count?: number;
  allowed_pm_usernames?: string[] | string;
  any_posts?: boolean;
  associated_account_avatars?: {
    id: number;
    name: string;
    upload_id: number;
    avatar_template: string;
  }[];
  associated_account_ids?: Record<string, string>;
  available_notification_types?: number[];
  badge_count?: number | null;
  badges?: UserBadgeModel[];
  bio_cooked?: string;
  bio_excerpt?: string;
  bio_raw?: string;
  can_be_deleted?: boolean;
  can_change_bio?: boolean;
  can_change_location?: boolean;
  can_change_post_owner?: true;
  can_change_tracking_preferences?: boolean;
  can_change_website?: boolean;
  can_create_admin_invite?: true;
  can_create_category?: true;
  can_create_group?: true;
  can_create_topic?: boolean;
  can_delete_account?: true;
  can_delete_all_posts?: boolean;
  can_delete_all_posts_and_topics?: boolean;
  can_edit?: boolean;
  can_edit_avatar?: boolean;
  can_edit_email?: boolean;
  can_edit_name?: boolean;
  can_edit_tags?: boolean;
  can_edit_username?: boolean;
  can_ignore_user?: boolean;
  can_ignore_users?: boolean;
  can_invite_to_forum?: true;
  can_localize_content?: boolean;
  can_mute_user?: boolean;
  can_mute_users?: boolean;
  can_pick_theme_with_custom_homepage?: boolean;
  can_post_anonymously?: boolean;
  can_review?: boolean;
  can_run_design_wizard?: true;
  can_see_emails?: boolean;
  can_see_ip?: boolean;
  can_send_private_email_messages?: boolean;
  can_send_private_message_to_user?: boolean;
  can_send_private_messages?: boolean;
  can_set_topic_timer?: boolean;
  can_upload_avatar?: boolean;
  can_upload_profile_header?: boolean;
  can_upload_user_card_background?: boolean;
  can_view_raw_email?: boolean;
  card_background_upload_url?: string;
  card_badge?: UserBadgeModel | null;
  created_at?: string;
  custom_avatar_template?: string;
  custom_avatar_upload_id?: number | null;
  custom_data?: unknown;
  custom_fields?: Record<string, unknown>;
  date_of_birth?: string | null;
  days_since_created?: number;
  days_visited?: number;
  display_sidebar_tags?: boolean;
  do_not_disturb_channel_position?: number;
  draft_count?: number;
  effective_locale?: string;
  email?: string | null;
  error?: boolean;
  external_id?: string | null;
  featured_topic?: {
    id: number;
    title: string;
    slug: string;
    fancy_title?: string;
  } | null;
  featured_user_badge_ids?: number[];
  featured_user_badges?: UserBadge[];
  finished?: boolean;
  flair_bg_color?: string | null;
  flair_color?: string | null;
  flair_group_id?: number | null;
  flair_name?: string | null;
  flair_url?: string | null;
  gravatar_avatar_template?: string;
  gravatar_avatar_upload_id?: number | null;
  grouped_unread_notifications?: Record<string, number>;
  has_new_upcoming_changes?: boolean;
  has_title_badges?: boolean;
  has_unseen_features?: boolean;
  hideReadOnlyAlert?: boolean;
  ignored?: boolean;
  impersonation_expires_at?: string | null;
  inactive?: boolean;
  indirectly_muted_category_ids?: number[];
  inviteLink?: string;
  invited_by?: User | null;
  isCurrent?: boolean;
  is_anonymous?: boolean;
  is_impersonating?: boolean;
  last_posted_at?: string | null;
  last_seen_at?: string | null;
  link_posting_access?: string;
  locale?: string | null;
  login_method?: string | null;
  mailing_list_posts_per_day?: number;
  moderator?: boolean;
  muted?: boolean;
  muted_category_ids?: number[];
  muted_tags?: (SiteTopTag | string)[];
  muted_topics?: { topicId: number; createdAt: number }[];
  muted_usernames?: string[] | string;
  name?: string | null;
  needs_required_fields_check?: boolean;
  new_personal_messages_notifications_count?: number;
  no_password?: true;
  notification_channel_position?: number | null;
  number_of_deleted_posts?: number;
  number_of_flags?: number;
  number_of_flags_given?: number;
  number_of_silencings?: number;
  number_of_suspensions?: number;
  owner?: boolean;
  pending_count?: number;
  pending_posts_count?: number;
  post_count?: number | null;
  posts_read_count?: number;
  previous_visit_at?: string | null;
  primary?: boolean;
  primary_group_id?: number | null;
  primary_group_name?: string | null;
  /** Legacy compatibility field; current serializers do not supply it. */
  private_messages_stats?: { all?: number; mine?: number; unread?: number };
  profile_background_upload_url?: string;
  profile_hidden?: true;
  profile_view_count?: number;
  read_faq?: boolean;
  read_first_notification?: boolean;
  recent_searches?: string[];
  recent_searches_detailed?: { term: string; at: string }[];
  recent_time_read?: number;
  regular_category_ids?: number[];
  regular_tags?: (SiteTopTag | string)[];
  request_accepted?: boolean;
  request_denied?: boolean;
  request_undone?: boolean;
  reviewable_count?: number;
  saving?: boolean;
  second_factor_backup_enabled?: boolean;
  second_factor_enabled?: boolean;
  second_factor_remaining_backup_codes?: number;
  seen_notification_id?: number;
  selected_user_associated_account_id?: number | null;
  show_mcp_authorizations?: boolean;
  show_site_owner_onboarding?: true;
  sidebar_category_ids?: number[];
  sidebar_tag_names?: string[];
  sidebar_tags?: SiteSidebarTag[];
  silence_reason?: string | null;
  silenced_till?: string | null;
  staged?: boolean;
  /** Legacy compatibility field; current serializers do not supply it. */
  stats?: UserActionStat[];
  suspend_reason?: string | null;
  suspended_till?: string | null;
  system_avatar_template?: string;
  system_avatar_upload_id?: number | null;
  time_read?: number | null;
  title?: string | null;
  top_category_ids?: number[];
  topic_count?: number | null;
  topics_entered?: number;
  topic_post_count?: Record<string, number>;
  tracked_category_ids?: number[];
  tracked_tags?: (SiteTopTag | string)[];
  trust_level?: number;
  unified_new_enabled?: boolean;
  unmuted_topics?: { topicId: number; createdAt: number }[];
  unread_high_priority_notifications?: number;
  unread_notifications?: number;
  unseen_reviewable_count?: number;
  uploaded_avatar_id?: number | null;
  use_logo_small_as_avatar?: boolean | string | null;
  user_api_keys?: UserApiKey[] | null;
  user_auth_tokens?: {
    id: number;
    client_ip?: string;
    location: string;
    browser: string;
    device: string;
    os: string;
    icon: string;
    created_at: string;
    seen_at: string;
    is_active?: boolean;
  }[];
  user_fields?: Record<string, string | string[] | boolean | null>;
  user_notification_schedule?: Partial<
    Record<`day_${0 | 1 | 2 | 3 | 4 | 5 | 6}_${"start" | "end"}_time`, number>
  > & { id?: number; user_id?: number; enabled: boolean };
  user_option?: UserOption;
  user_passkeys?: {
    id: number;
    name: string;
    last_used: string | null;
    created_at: string;
  }[];
  viewingSelf?: boolean;
  visibleGroups?: UserGroup[];
  watched_category_ids?: number[];
  watched_first_post_category_ids?: number[];
  watched_tags?: (SiteTopTag | string)[];
  watching_first_post_tags?: (SiteTopTag | string)[];
  website?: string;
  website_name?: string;
  whisperer?: boolean;
}

/** Creation accepts raw groups without exposing a writable deprecated groups getter. */
export type UserCreateAttrs<M = User> = Partial<
  Omit<M, "groups" | "trust_level" | "avatar_template">
> &
  RestModelStoreAttrs & {
    groups?: UserGroup[];
    /** Embedded post authors can carry null before hydration. */
    trust_level?: number | null;
    avatar_template?: string | null;
  };

/** findDetails consumes forCard by deleting it from the caller's options. */
export interface UserFindDetailsOptions {
  forCard?: boolean;
  existingRequest?: PromiseLike<UserDetailsResponse>;
  include_post_count_for?: number;
  [key: string]: unknown;
}

/** Raw profile/card data before findDetails replaces its relationships. */
export interface UserDetailsResponse {
  user: Omit<Partial<UserFields>, "stats" | "invited_by" | "card_badge"> & {
    stats?:
      | (Omit<Partial<UserActionStat>, "count"> & { count?: number | string })[]
      | UserActionStat[];
    groups?: (RestModelAttrs<Group> & Pick<UserGroup, "id" | "name">)[];
    group_users?: UserGroup["group_user"][];
    invited_by?: UserCreateAttrs | User | null;
    card_badge?: RestPayload | UserBadgeModel | null;
    timezone?: string | null;
  };
  [key: string]: unknown;
}

/** Activity summary, enriched with model instances, dates and links by summary(). */
export interface UserSummary {
  likes_given?: number;
  likes_received?: number;
  topics_entered?: number;
  posts_read_count?: number;
  days_visited?: number;
  topic_count?: number;
  post_count?: number;
  time_read?: number;
  recent_time_read?: number;
  bookmark_count?: number;
  can_see_summary_stats: boolean;
  can_see_user_actions: boolean;
  topic_ids: number[];
  topics: Topic[];
  replies: {
    topic_id: number;
    post_number: number;
    created_at: string;
    like_count: number;
    topic: Topic;
    url: string;
    createdAt: Date;
  }[];
  links: {
    topic_id: number;
    post_number: number;
    url: string;
    clicks: number;
    title: string | null;
    topic: Topic;
    post_url: string;
  }[];
  most_liked_by_users: (TopicBasicUser & { count: number })[];
  most_liked_users: (TopicBasicUser & { count: number })[];
  most_replied_to_users: (TopicBasicUser & { count: number })[];
  badges?: UserBadgeModel[];
  top_categories?: (Partial<Category> & {
    parent_category_id?: number | null;
    parentCategory?: Category;
  })[];
}

/** Signup form inputs; plugin-added request data is supplied by the transformer. */
export interface UserAccountAttrs {
  accountName?: string;
  accountEmail: string;
  accountPassword?: string;
  accountUsername: string;
  accountPasswordConfirm?: string;
  accountChallenge?: string;
  userFields?: UserFields["user_fields"];
  inviteCode?: string;
}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default interface User extends UserFields, Evented {}

export const SECOND_FACTOR_METHODS = {
  TOTP: 1,
  BACKUP_CODE: 2,
  SECURITY_KEY: 3,
  PASSKEY: 4,
};

export const MAX_SECOND_FACTOR_NAME_LENGTH = 300;

const TEXT_SIZE_COOKIE_NAME = "text_size";
const COOKIE_EXPIRY_DAYS = 365;

export function extendTextSizeCookie() {
  const currentValue = cookie(TEXT_SIZE_COOKIE_NAME);
  if (currentValue) {
    cookie(TEXT_SIZE_COOKIE_NAME, currentValue, {
      path: "/",
      expires: COOKIE_EXPIRY_DAYS,
    });
  }
}

const isForever = (dt: MomentInput) => moment().diff(dt, "years") < -100;

let userFields = [
  "allowed_pm_usernames",
  "bio_raw",
  "card_background_upload_url",
  "custom_fields",
  "date_of_birth",
  "flair_group_id",
  "ignored_usernames",
  "locale",
  "location",
  "muted_tags",
  "muted_usernames",
  "name",
  "primary_group_id",
  "profile_background_upload_url",
  "sidebar_category_ids",
  "sidebar_tag_names",
  "status",
  "title",
  "tracked_tags",
  "user_fields",
  "user_notification_schedule",
  "watched_tags",
  "watching_first_post_tags",
  "website",
];

export function addSaveableUserField(fieldName: string) {
  userFields.push(fieldName);
}

let userOptionFields = [
  "allow_private_messages",
  "auto_track_topics_after_msecs",
  "automatically_unpin_topics",
  "bookmark_auto_delete_preference",
  "color_scheme_id",
  "composition_mode",
  "dark_scheme_id",
  "default_calendar",
  "digest_after_minutes",
  "dynamic_favicon",
  "email_digests",
  "email_in_reply_to",
  "email_level",
  "email_messages_level",
  "email_previous_replies",
  "enable_allowed_pm_users",
  "enable_markdown_monospace_font",
  "enable_quoting",
  "enable_smart_lists",
  "enable_upcoming_change_available_notifications",
  "external_links_in_new_tab",
  "hidden_composer_toolbar_buttons",
  "hide_presence",
  "hide_profile",
  "homepage_id",
  "include_tl0_in_digests",
  "interface_color_mode",
  "like_notification_frequency",
  "mailing_list_mode",
  "mailing_list_mode_frequency",
  "new_topic_duration_minutes",
  "notification_level_when_replying",
  "notify_on_linked_posts",
  "push_notification_level",
  "seen_popups",
  "send_shortcut",
  "automatically_translate",
  "show_original_content",
  "sidebar_link_to_filtered_list",
  "sidebar_show_count_of_new_items",
  "skip_new_user_tips",
  "text_size",
  "theme_ids",
  "timezone",
  "title_count_mode",
  "understood_languages",
  "watched_precedence_over_muted",
];

export function addSaveableUserOptionField(fieldName: string) {
  userOptionFields.push(fieldName);
}

function userOption(userOptionKey: keyof UserOption) {
  return computed(`user_option.${userOptionKey}`, {
    get(this: User, key: string) {
      deprecated(
        `Getting ${key} property of user object is deprecated. Use user_option object instead`,
        {
          id: "discourse.user.userOptions",
          since: "2.9.0.beta12",
        }
      );

      return this.get(`user_option.${key}`);
    },

    set(this: User, key: string, value: unknown) {
      deprecated(
        `Setting ${key} property of user object is deprecated. Use user_option object instead`,
        {
          id: "discourse.user.userOptions",
          since: "2.9.0.beta12",
        }
      );

      if (!this.user_option) {
        this.set("user_option", {});
      }

      return this.set(`user_option.${key}`, value);
    },
  });
}

@singleton
// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class User extends RestModel.extend(Evented) {
  /** Added by `@singleton`; anonymous sessions have no current user. */
  declare static current: () => User | null;

  /** Reads or writes a current-user property; returns undefined for anonymous sessions. */
  declare static currentProp: {
    <K extends keyof User>(property: K): User[K] | undefined;
    <K extends keyof User>(property: K, value: User[K]): User[K] | undefined;
    <P extends string>(
      property: P extends keyof User ? never : P,
      value?: unknown
    ): unknown;
  };

  /** Replaces the singleton value without constructing or hydrating it. */
  declare static resetCurrent: <T extends User | null | undefined = undefined>(
    value?: T
  ) => T;

  /** Runtime implementation stays in reopenClass for its _super chain; it mutates groups and tracking fields in its input. */
  declare static create: <C extends RestModelClass>(
    this: C,
    attrs?: UserCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  declare static findByUsername: (
    username: string,
    options?: UserFindDetailsOptions
  ) => globalThis.Promise<User>;
  declare static checkUsername: (
    username?: string | null,
    email?: string | null,
    for_user_id?: number
  ) => globalThis.Promise<unknown>;
  declare static checkEmail: (email: string) => globalThis.Promise<unknown>;
  declare static loadRecentSearches: () => globalThis.Promise<unknown>;
  declare static resetRecentSearches: () => globalThis.Promise<unknown>;
  declare static groupStats: (stats: UserActionStat[]) => UserActionStat[];
  declare static createAccount: (
    attrs: UserAccountAttrs
  ) => globalThis.Promise<unknown>;
  declare static deleteStatusTrackingFields: (args: RestPayload) => void;

  static createCurrent(): User | null {
    // TODO(typescript-pending): PreloadStore has no payload contracts; remove when its keys are typed.
    const userJson = PreloadStore.get("currentUser") as
      | (UserCreateAttrs & {
          username: string;
          user_option: UserOption;
          visibleGroups?: UserGroup[];
        })
      | undefined;
    if (userJson) {
      userJson.isCurrent = true;

      // Calling user.groups is deprecated, see discourse.user.groups,
      // it is replaced by visibleGroups
      if (
        !Object.hasOwn(userJson, "visibleGroups") &&
        Object.hasOwn(userJson, "groups")
      ) {
        userJson.visibleGroups = userJson.groups;
        delete userJson.groups;
      }

      if (userJson.primary_group_id) {
        const primaryGroup = userJson.visibleGroups!.find(
          (group) => group.id === userJson.primary_group_id
        );
        if (primaryGroup) {
          userJson.primary_group_name = primaryGroup.name;
        }
      }

      if (!userJson.user_option.timezone) {
        userJson.user_option.timezone = moment.tz.guess();
        this._saveTimezone(userJson);
      }

      const store = getOwnerWithFallback(this).lookup(
        "service:store"
      ) as StoreService;
      const currentUser = store.createRecord("user", userJson);
      currentUser.statusManager.trackStatus();
      return currentUser;
    }

    return null;
  }

  @service appEvents!: AppEventsService;

  @tracked do_not_disturb_until: string | null | undefined;

  @tracked status: UserStatus | null | undefined;

  @tracked dismissed_banner_key: number | null | undefined;

  @autoTrackedArray
  associated_accounts: { name: string; description: string }[] | undefined;

  @autoTrackedArray ignored_usernames: string[] | undefined;
  @autoTrackedArray ignored_users: string[] | undefined;
  @autoTrackedArray secondary_emails: string[] | undefined;
  @autoTrackedArray sidebar_sections: SiteSidebarSection[] | undefined;
  @autoTrackedArray unconfirmed_emails: string[] | undefined;
  @userOption("mailing_list_mode")
  mailing_list_mode: UserOption["mailing_list_mode"];
  @userOption("external_links_in_new_tab")
  external_links_in_new_tab: UserOption["external_links_in_new_tab"];
  @userOption("enable_quoting") enable_quoting: UserOption["enable_quoting"];
  @userOption("enable_smart_lists")
  enable_smart_lists: UserOption["enable_smart_lists"];

  @userOption("enable_markdown_monospace_font")
  enable_markdown_monospace_font: UserOption["enable_markdown_monospace_font"];
  @userOption("dynamic_favicon") dynamic_favicon: UserOption["dynamic_favicon"];
  @userOption("automatically_unpin_topics")
  automatically_unpin_topics: UserOption["automatically_unpin_topics"];
  @userOption("likes_notifications_disabled")
  likes_notifications_disabled: UserOption["likes_notifications_disabled"];
  @userOption("hide_profile") hide_profile: UserOption["hide_profile"];
  @userOption("hide_presence") hide_presence: UserOption["hide_presence"];
  @userOption("title_count_mode")
  title_count_mode: UserOption["title_count_mode"];
  @userOption("timezone") timezone: UserOption["timezone"];
  @userOption("skip_new_user_tips")
  skip_new_user_tips: UserOption["skip_new_user_tips"];
  @userOption("default_calendar")
  default_calendar: UserOption["default_calendar"];
  @userOption("bookmark_auto_delete_preference")
  bookmark_auto_delete_preference: UserOption["bookmark_auto_delete_preference"];
  @userOption("seen_popups") seen_popups: UserOption["seen_popups"];
  @userOption("should_be_redirected_to_top")
  should_be_redirected_to_top: UserOption["should_be_redirected_to_top"];
  @userOption("redirected_to_top")
  redirected_to_top: UserOption["redirected_to_top"];
  @userOption("treat_as_new_topic_start_date")
  treat_as_new_topic_start_date: UserOption["treat_as_new_topic_start_date"];
  @userOption("composition_mode")
  composition_mode: UserOption["composition_mode"];
  numGroupsToDisplay = 2;
  statusManager = new UserStatusManager(this);
  declare static _current: User | null | undefined;
  declare static _saveTimezone: (user: {
    username: string;
    user_option: UserOption;
  }) => void;

  @tracked _location: string | null | undefined;

  @computed("sidebar_category_ids")
  get sidebarCategoryIds() {
    return this.sidebar_category_ids;
  }

  set sidebarCategoryIds(value: number[] | undefined) {
    set(this, "sidebar_category_ids", value);
  }

  @dependentKeyCompat
  get sidebarSections() {
    return this.sidebar_sections;
  }

  set sidebarSections(value: SiteSidebarSection[] | undefined) {
    this.sidebar_sections = value;
  }

  @dependentKeyCompat
  get location() {
    return applyValueTransformer("user-location", this._location, {
      user: this,
    });
  }

  set location(value: string | null | undefined) {
    this._location = value;
  }

  @computed("can_pick_theme_with_custom_homepage")
  get canPickThemeWithCustomHomepage() {
    return this.can_pick_theme_with_custom_homepage;
  }

  set canPickThemeWithCustomHomepage(value: boolean | undefined) {
    set(this, "can_pick_theme_with_custom_homepage", value);
  }

  @computed("can_edit_tags")
  get canEditTags() {
    return this.can_edit_tags;
  }

  set canEditTags(value: boolean | undefined) {
    set(this, "can_edit_tags", value);
  }

  @computed("can_change_post_owner")
  get canChangePostOwner() {
    return this.can_change_post_owner;
  }

  set canChangePostOwner(value: boolean | undefined) {
    set(this, "can_change_post_owner", value);
  }

  @computed("admin", "moderator")
  get staff() {
    return this.admin || this.moderator;
  }

  /** Prevents the staff property from being overridden. */
  set staff(value: boolean | undefined) {}

  @dependentKeyCompat
  get mutedCategories() {
    if (
      this.site.lazy_load_categories &&
      this.muted_category_ids &&
      !Category.hasAsyncFoundAll(this.muted_category_ids)
    ) {
      Category.asyncFindByIds(this.muted_category_ids).then(() =>
        this.notifyPropertyChange("muted_category_ids")
      );
    }

    return Category.findByIds(this.get("muted_category_ids"));
  }

  set mutedCategories(categories: Category[]) {
    this.set(
      "muted_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get regularCategories() {
    if (
      this.site.lazy_load_categories &&
      this.regular_category_ids &&
      !Category.hasAsyncFoundAll(this.regular_category_ids)
    ) {
      Category.asyncFindByIds(this.regular_category_ids).then(() =>
        this.notifyPropertyChange("regular_category_ids")
      );
    }

    return Category.findByIds(this.get("regular_category_ids"));
  }

  set regularCategories(categories: Category[]) {
    this.set(
      "regular_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get trackedCategories() {
    if (
      this.site.lazy_load_categories &&
      this.tracked_category_ids &&
      !Category.hasAsyncFoundAll(this.tracked_category_ids)
    ) {
      Category.asyncFindByIds(this.tracked_category_ids).then(() =>
        this.notifyPropertyChange("tracked_category_ids")
      );
    }

    return Category.findByIds(this.get("tracked_category_ids"));
  }

  set trackedCategories(categories: Category[]) {
    this.set(
      "tracked_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get watchedCategories() {
    if (
      this.site.lazy_load_categories &&
      this.watched_category_ids &&
      !Category.hasAsyncFoundAll(this.watched_category_ids)
    ) {
      Category.asyncFindByIds(this.watched_category_ids).then(() =>
        this.notifyPropertyChange("watched_category_ids")
      );
    }

    return Category.findByIds(this.get("watched_category_ids"));
  }

  set watchedCategories(categories: Category[]) {
    this.set(
      "watched_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get watchedFirstPostCategories() {
    if (
      this.site.lazy_load_categories &&
      this.watched_first_post_category_ids &&
      !Category.hasAsyncFoundAll(this.watched_first_post_category_ids)
    ) {
      Category.asyncFindByIds(this.watched_first_post_category_ids).then(() =>
        this.notifyPropertyChange("watched_first_post_category_ids")
      );
    }

    return Category.findByIds(this.get("watched_first_post_category_ids"));
  }

  set watchedFirstPostCategories(categories: Category[]) {
    this.set(
      "watched_first_post_category_ids",
      categories.map((c) => c.id)
    );
  }

  @computed("private_messages_stats.all")
  get hasPMs() {
    return (this.private_messages_stats?.all as number) > 0;
  }

  @computed("private_messages_stats.mine")
  get hasStartedPMs() {
    return (this.private_messages_stats?.mine as number) > 0;
  }

  @computed("private_messages_stats.unread")
  get hasUnreadPMs() {
    return (this.private_messages_stats?.unread as number) > 0;
  }

  @computed("id", "username_lower")
  get adminPath(): string {
    return getURL(`/admin/users/${this.id}/${this.username_lower}`);
  }

  @computed("trust_level")
  get isBasic() {
    return this.trust_level === 0;
  }

  @computed("trust_level")
  get isRegular() {
    return this.trust_level === 3;
  }

  @computed("trust_level")
  get isLeader() {
    return this.trust_level === 4;
  }

  @computed("staff", "isLeader")
  get canManageTopic() {
    return this.staff || this.isLeader;
  }

  @computed("can_set_topic_timer", "canManageTopic")
  get canSetTopicTimer() {
    return this.can_set_topic_timer ?? this.canManageTopic;
  }

  @computed("sidebarTags.@each.name")
  get sidebarTagNames() {
    return this.sidebarTags?.map?.((item) => item.name) ?? [];
  }

  @computed("visibleGroups.@each.has_messages")
  get groupsWithMessages() {
    return (
      this.visibleGroups?.filter?.((item) => item.has_messages === true) ?? []
    );
  }

  @computed("user_option.composition_mode")
  get useRichEditor() {
    return (
      this.user_option?.composition_mode === USER_OPTION_COMPOSITION_MODES.rich
    );
  }

  @computed("can_be_deleted", "post_count")
  get canBeDeleted() {
    const maxPostCount = this.siteSettings.delete_all_posts_max;
    return this.can_be_deleted && this.post_count! <= (maxPostCount as number);
  }

  @computed()
  get stream(): UserStream {
    return UserStream.create({ user: this });
  }

  @computed()
  get bookmarks(): Bookmark {
    // TODO(typescript-pending): Bookmark.create returns its base wrapper; remove when Bookmark is typed.
    return Bookmark.create({ user: this }) as Bookmark;
  }

  @computed()
  get postsStream(): UserPostsStream {
    return UserPostsStream.create({ user: this });
  }

  @computed()
  get userDraftsStream(): UserDraftsStream {
    return UserDraftsStream.create({ user: this });
  }

  get groups() {
    deprecated(
      "Calling user.groups is deprecated, use user.visibleGroups instead, it more accurately reflects what this array of groups represents, not all of the user's group memberships may be serialized to the client. For permission checks, check the user's groups server-side and add an attribute to the User/CurrentUserSerializer, or use `resolve_group_memberships: true` for theme settings.",
      {
        id: "discourse.user.groups",
        since: "2026.8.0-latest.1",
        url: "https://meta.discourse.org/t/-/411124",
      }
    );
    return this.visibleGroups;
  }

  @computed("has_unseen_features")
  get hasUnseenFeatures() {
    return this.staff && this.get("has_unseen_features");
  }

  @computed("has_new_upcoming_changes")
  get hasNewUpcomingChanges() {
    return this.staff && this.get("has_new_upcoming_changes");
  }

  @computed("username_lower")
  get searchContext(): { type: string; id: string; user: User } {
    return {
      type: "user",
      id: this.username_lower,
      user: this,
    };
  }

  @computed("username", "name")
  get displayName(): string {
    if (this.siteSettings.enable_names && !isEmpty(this.name)) {
      return this.name!;
    }
    return this.username;
  }

  @computed("profile_background_upload_url")
  get profileBackgroundUrl() {
    if (
      isEmpty(this.profile_background_upload_url) ||
      !this.siteSettings.allow_profile_backgrounds
    ) {
      return trustHTML("");
    }
    return trustHTML(
      "background-image: url(" +
        getURLWithCDN(this.profile_background_upload_url) +
        ")"
    );
  }

  @computed()
  get path(): string {
    // no need to observe, requires a hard refresh to update
    return applyValueTransformer("user-path", userPath(this.username_lower), {
      user: this,
    });
  }

  @computed()
  get userApiKeys(): WrappedUserApiKey[] | undefined {
    const keys = this.user_api_keys;
    if (keys) {
      return keys.map((raw) => {
        // The callbacks are installed immediately after wrapping the serialized key.
        let obj = EmberObject.create(
          raw as Partial<EmberObject>
        ) as WrappedUserApiKey;

        obj.revoke = () => {
          this.revokeApiKey(obj);
        };

        obj.undoRevoke = () => {
          this.undoRevokeApiKey(obj);
        };

        return obj;
      });
    }
  }

  @computed()
  get mutedTopicsPath(): string {
    return defaultHomepage() === "latest"
      ? getURL("/?state=muted")
      : getURL("/latest?state=muted");
  }

  @computed()
  get watchingTopicsPath(): string {
    return defaultHomepage() === "latest"
      ? getURL("/?state=watching")
      : getURL("/latest?state=watching");
  }

  @computed()
  get trackingTopicsPath(): string {
    return defaultHomepage() === "latest"
      ? getURL("/?state=tracking")
      : getURL("/latest?state=tracking");
  }

  @computed("username")
  get username_lower() {
    return this.username.toLowerCase();
  }

  @computed("trust_level")
  get trustLevel() {
    return Site.currentProp("trustLevels")!.find(
      (l) => l.id === parseInt(this.trust_level as unknown as string, 10)
    );
  }

  @computed("previous_visit_at")
  /** Missing and null timestamps retain the Date constructor's legacy coercion. */
  get previousVisitAt() {
    return new Date(this.previous_visit_at as string);
  }

  @computed("suspended_till")
  /** Retains the timestamp's falsey value rather than normalizing it to false. */
  get suspended() {
    return this.suspended_till && moment(this.suspended_till).isAfter();
  }

  @computed("suspended_till")
  get suspendedForever() {
    return isForever(this.suspended_till);
  }

  @computed("silenced_till")
  get silenced() {
    return this.silenced_till && moment(this.silenced_till).isAfter();
  }

  @computed("silenced_till")
  get silencedForever() {
    return isForever(this.silenced_till);
  }

  @computed("suspended_till")
  get suspendedTillDate() {
    return longDate(this.suspended_till);
  }

  @computed("silenced_till")
  get silencedTillDate() {
    return longDate(this.silenced_till);
  }

  @computed("sidebar_tags.[]")
  get sidebarTags() {
    if (!this.sidebar_tags || this.sidebar_tags?.length === 0) {
      return [];
    }

    return this.sidebar_tags?.sort((a, b) => {
      return a.name.localeCompare(b.name);
    });
  }

  @computed("visibleGroups.[]")
  get filteredGroups() {
    const groups = this.visibleGroups || [];

    return groups.filter((group) => {
      return !group.automatic || group.id === AUTO_GROUPS.moderators.id;
    });
  }

  @computed("filteredGroups", "numGroupsToDisplay")
  get displayGroups() {
    const groups = this.filteredGroups.slice(0, this.numGroupsToDisplay);
    return groups.length === 0 ? null : groups;
  }

  /** The user's stat count, excluding PMs. */
  @computed("statsExcludingPms.@each.count")
  get statsCountNonPM() {
    if (isEmpty(this.statsExcludingPms)) {
      return 0;
    }
    let count = 0;
    this.statsExcludingPms.forEach((val) => {
      if (this.inAllStream(val)) {
        count += val.count;
      }
    });
    return count;
  }

  /** The user's stats, excluding PMs. */
  @computed("stats.@each.isPM")
  get statsExcludingPms(): UserActionStat[] {
    if (isEmpty(this.stats)) {
      return [];
    }
    return this.stats!.filter((stat) => !stat.isPM);
  }

  @computed("can_delete_account")
  get canDeleteAccount() {
    return (
      !this.siteSettings.enable_discourse_connect && this.can_delete_account
    );
  }

  @dependentKeyCompat
  get sidebarLinkToFilteredList() {
    // Nested property paths use the framework getter's unknown overload.
    return this.get(
      "user_option.sidebar_link_to_filtered_list"
    ) as UserOption["sidebar_link_to_filtered_list"];
  }

  @dependentKeyCompat
  get sidebarShowCountOfNewItems() {
    return this.get(
      "user_option.sidebar_show_count_of_new_items"
    ) as UserOption["sidebar_show_count_of_new_items"];
  }

  @computed("visibleGroups.@each.title", "badges.[]")
  get availableTitles(): { name: string; id: string }[] {
    const titles: string[] = [];

    (this.visibleGroups || []).forEach((group) => {
      if (get(group, "title")) {
        titles.push(get(group, "title")!);
      }
    });

    (this.badges || []).forEach((badge) => {
      if (get(badge, "allow_title")) {
        titles.push(get(badge, "name"));
      }
    });

    return (uniqueItemsFromArray(titles) as string[]).sort().map((title) => {
      return {
        name: escapeExpression(title),
        id: title,
      };
    });
  }

  @computed("visibleGroups.[]")
  get availableFlairs() {
    const flairs: {
      id: number;
      name: string;
      url: string;
      bgColor?: string | null;
      color?: string | null;
    }[] = [];

    if (this.visibleGroups) {
      this.visibleGroups.forEach((group) => {
        if (group.flair_url) {
          flairs.push({
            id: group.id,
            name: group.name,
            url: group.flair_url,
            bgColor: group.flair_bg_color,
            color: group.flair_color,
          });
        }
      });
    }

    return flairs;
  }

  @computed("user_option.text_size_seq", "user_option.text_size")
  get currentTextSize() {
    if (cookie(TEXT_SIZE_COOKIE_NAME)) {
      const [cookieSize, cookieSeq] = (
        cookie(TEXT_SIZE_COOKIE_NAME) as string
      ).split("|");
      if (cookieSeq >= (this.user_option?.text_size_seq as unknown as string)) {
        return cookieSize;
      }
    }
    return this.user_option?.text_size;
  }

  @computed("second_factor_enabled", "staff")
  get enforcedSecondFactor() {
    const enforce = this.siteSettings.enforce_second_factor;
    return (
      !this.second_factor_enabled &&
      (enforce === "all" || (enforce === "staff" && this.staff))
    );
  }

  @computed("tracked_tags.[]", "watched_tags.[]", "watching_first_post_tags.[]")
  get trackedTags() {
    return [
      ...(this.tracked_tags || []),
      ...(this.watched_tags || []),
      ...(this.watching_first_post_tags || []),
    ];
  }

  get prefersLightColor() {
    return (
      this.user_option?.interface_color_mode === INTERFACE_COLOR_MODES.LIGHT
    );
  }

  get prefersDarkColor() {
    return (
      this.user_option?.interface_color_mode === INTERFACE_COLOR_MODES.DARK
    );
  }

  /** The legacy lookup uses an absent constant key, so unset modes also match. */
  get prefersAutoColor() {
    return (
      this.user_option?.interface_color_mode ===
      (
        INTERFACE_COLOR_MODES as typeof INTERFACE_COLOR_MODES & {
          AUTODARK?: number;
        }
      ).AUTODARK
    );
  }

  destroySession(
    pushSubscription?: PushSubscriptionJSON | null
  ): globalThis.Promise<unknown> {
    const data: { push_subscription?: PushSubscriptionJSON } = {};
    if (pushSubscription) {
      data.push_subscription = pushSubscription;
    }
    return ajax(`/session/${this.username}`, { type: "DELETE", data });
  }

  revokeApiKey(key: EmberObject & UserApiKey) {
    return ajax("/user-api-key/revoke", {
      type: "POST",
      data: { id: key.get("id") },
    }).then(() => {
      key.set("revoked", true);
    });
  }

  undoRevokeApiKey(key: EmberObject & UserApiKey) {
    return ajax("/user-api-key/undo-revoke", {
      type: "POST",
      data: { id: key.get("id") },
    }).then(() => {
      key.set("revoked", false);
    });
  }

  pmPath(topic: Topic): string | undefined {
    const username = this.username_lower;
    // TODO(typescript-pending): TopicDetails omits allowed-user/group fields; remove when TopicDetails is typed.
    const details = topic.details as Omit<
      Topic["details"],
      "allowed_users" | "allowed_groups"
    > & {
      allowed_users?: TopicBasicUser[];
      allowed_groups?: { id: number; name: string }[];
    };
    const allowedUsers = details?.allowed_users;
    const groups = details?.allowed_groups;

    // directly targeted so go to inbox
    if (!groups || allowedUsers?.find((user) => user.id === this.id)) {
      return userPath(`${username}/messages`);
    } else if (groups) {
      const firstAllowedGroup = groups.find((allowedGroup) =>
        this.visibleGroups!.some(
          (userGroup) => userGroup.id === allowedGroup.id
        )
      );

      if (firstAllowedGroup) {
        return userPath(`${username}/messages/group/${firstAllowedGroup.name}`);
      }
    }
  }

  changeUsername(new_username: string): globalThis.Promise<unknown> {
    return ajax(userPath(`${this.username_lower}/preferences/username`), {
      type: "PUT",
      data: { new_username },
    });
  }

  addEmail(email: string) {
    return ajax(userPath(`${this.username_lower}/preferences/email`), {
      type: "POST",
      data: { email },
    }).then(() => {
      if (!this.unconfirmed_emails) {
        this.set("unconfirmed_emails", []);
      }

      if (!this.unconfirmed_emails!.includes(email)) {
        this.unconfirmed_emails!.push(email);
      }
    });
  }

  changeEmail(email: string) {
    return ajax(userPath(`${this.username_lower}/preferences/email`), {
      type: "PUT",
      data: { email },
    }).then(() => {
      if (!this.unconfirmed_emails) {
        this.set("unconfirmed_emails", []);
      }

      this.unconfirmed_emails!.push(email);
    });
  }

  override save(fields?: string[]) {
    const data = this.getProperties(
      userFields.filter((uf) => !fields || fields.includes(uf))
    ) as Record<string, unknown>;

    const filteredUserOptionFields = fields
      ? userOptionFields.filter((uo) => fields.includes(uo))
      : userOptionFields;

    filteredUserOptionFields.forEach((s) => {
      data[s] = this.get(`user_option.${s}`);
    });

    const updatedState: Partial<UserFields> = {};

    ["muted", "regular", "watched", "tracked", "watched_first_post"].forEach(
      (categoryNotificationLevel) => {
        if (
          fields === undefined ||
          fields.includes(`${categoryNotificationLevel}_category_ids`)
        ) {
          const categories = this.get(
            `${camelize(categoryNotificationLevel)}Categories`
          ) as Category[] | undefined;

          if (categories) {
            const ids = categories.map((c) => c.get("id")!);
            updatedState[
              `${categoryNotificationLevel}_category_ids` as "muted_category_ids"
            ] = ids;
            // HACK: Empty arrays are not sent in the request, we use [-1],
            // an invalid category ID, that will be ignored by the server.
            data[`${categoryNotificationLevel}_category_ids`] =
              ids.length === 0 ? [-1] : ids;
          }
        }
      }
    );

    [
      "muted_tags",
      "tracked_tags",
      "watched_tags",
      "watching_first_post_tags",
    ].forEach((prop) => {
      if (fields === undefined || fields.includes(prop)) {
        const tags = this.get(prop) as (SiteTopTag | string)[] | undefined;
        if (tags) {
          const names = tags.map((t) => (typeof t === "object" ? t.name : t));
          data[prop] = names.join(",");
        } else {
          data[prop] = "";
        }
      }
    });

    ["sidebar_category_ids", "sidebar_tag_names"].forEach((prop) => {
      if ((data[prop] as unknown[] | null | undefined)?.length === 0) {
        data[prop] = null;
      }
    });

    // TODO: We can remove this when migrated fully to rest model.
    this.set("isSaving", true);
    return ajax(userPath(`${this.username_lower}.json`), {
      data,
      type: "PUT",
    })
      .then(
        (
          result: RestModelSaveResult<this> & { user: { bio_excerpt?: string } }
        ) => {
          this.setProperties(updatedState);
          this.setProperties(getProperties(result.user, "bio_excerpt"));
          return result;
        }
      )
      .finally(() => {
        this.set("isSaving", false);
      });
  }

  setPrimaryEmail(email: string) {
    return ajax(userPath(`${this.username}/preferences/primary-email.json`), {
      type: "PUT",
      data: { email },
    }).then(() => {
      removeValueFromArray(this.secondary_emails!, email);
      this.secondary_emails!.push(this.email!);
      this.set("email", email);
    });
  }

  async destroyEmail(email: string) {
    await ajax(userPath(`${this.username}/preferences/email.json`), {
      type: "DELETE",
      data: { email },
    });

    removeValueFromArray(
      this.unconfirmed_emails!.includes(email)
        ? this.unconfirmed_emails!
        : this.secondary_emails!,
      email
    );
  }

  changePassword(): globalThis.Promise<unknown> {
    return ajax("/session/forgot_password.json", {
      data: { login: this.email || this.username },
      type: "POST",
    });
  }

  async removePassword(): globalThis.Promise<unknown> {
    return ajax(userPath(`${this.username}/remove-password`), {
      type: "PUT",
    });
  }

  loadSecondFactorCodes(): globalThis.Promise<unknown> {
    return ajax("/u/second_factors.json", {
      type: "POST",
    });
  }

  requestSecurityKeyChallenge(): globalThis.Promise<unknown> {
    return ajax("/u/create_second_factor_security_key.json", {
      type: "POST",
    });
  }

  registerSecurityKey(credential: object): globalThis.Promise<unknown> {
    return ajax("/u/register_second_factor_security_key.json", {
      data: credential,
      type: "POST",
    });
  }

  trustedSession(): globalThis.Promise<unknown> {
    return ajax("/u/trusted-session.json");
  }

  createPasskey(): globalThis.Promise<unknown> {
    return ajax("/u/create_passkey.json", {
      type: "POST",
    });
  }

  registerPasskey(credential: object): globalThis.Promise<unknown> {
    return ajax("/u/register_passkey.json", {
      data: credential,
      type: "POST",
    });
  }

  deletePasskey(id: number): globalThis.Promise<unknown> {
    return ajax(`/u/delete_passkey/${id}`, {
      type: "DELETE",
    });
  }

  createSecondFactorTotp(): globalThis.Promise<unknown> {
    return ajax("/u/create_second_factor_totp.json", {
      type: "POST",
    });
  }

  enableSecondFactorTotp(
    authToken: string,
    name: string
  ): globalThis.Promise<unknown> {
    return ajax("/u/enable_second_factor_totp.json", {
      data: {
        second_factor_token: authToken,
        name,
      },
      type: "POST",
    });
  }

  disableAllSecondFactors(): globalThis.Promise<unknown> {
    return ajax("/u/disable_second_factor.json", {
      type: "PUT",
    });
  }

  updateSecondFactor(
    id: number,
    name: string,
    disable: boolean,
    targetMethod?: number
  ): globalThis.Promise<unknown> {
    return ajax("/u/second_factor.json", {
      data: {
        second_factor_target: targetMethod,
        name,
        disable,
        id,
      },
      type: "PUT",
    });
  }

  updateSecurityKey(
    id: number,
    name: string,
    disable: boolean
  ): globalThis.Promise<unknown> {
    return ajax("/u/security_key.json", {
      data: {
        name,
        disable,
        id,
      },
      type: "PUT",
    });
  }

  toggleSecondFactor(
    authToken: string,
    authMethod: number,
    targetMethod: number,
    enable: boolean
  ): globalThis.Promise<unknown> {
    return ajax("/u/second_factor.json", {
      data: {
        second_factor_token: authToken,
        second_factor_method: authMethod,
        second_factor_target: targetMethod,
        enable,
      },
      type: "PUT",
    });
  }

  generateSecondFactorCodes(): globalThis.Promise<unknown> {
    return ajax("/u/second_factors_backup.json", {
      type: "PUT",
    });
  }

  revokeAssociatedAccount(providerName: string): globalThis.Promise<unknown> {
    return ajax(userPath(`${this.username}/preferences/revoke-account`), {
      data: { provider_name: providerName },
      type: "POST",
    });
  }

  async loadUserAction(id: number) {
    const result = await ajax<{
      user_action?: UserActionFields & RestPayload;
    }>(`/user_actions/${id}.json`);

    if (!result?.user_action) {
      return;
    }

    const ua = result.user_action;

    if ((this.get("stream.filter") || ua.action_type) !== ua.action_type) {
      return;
    }

    if (!this.get("stream.filter") && !this.inAllStream(ua)) {
      return;
    }

    ua.title = emojiUnescape(escapeExpression(ua.title));
    const action = UserAction.collapseStream([UserAction.create(ua)]);
    this.stream.itemsLoaded += 1;
    this.stream.content.unshift(action[0]);
  }

  inAllStream(ua: { action_type: number | null }) {
    return (
      ua.action_type === UserAction.TYPES.posts ||
      ua.action_type === UserAction.TYPES.topics
    );
  }

  /** Hydrates this instance and consumes options.forCard in place. */
  findDetails(options?: UserFindDetailsOptions): globalThis.Promise<User> {
    // eslint-disable-next-line @typescript-eslint/no-this-alias -- Preserve the callback receiver in this types-only port.
    const user = this;

    return PreloadStore.getAndRemove(`user_${user.get("username")}`, () => {
      if (options && options.existingRequest) {
        // Existing ajax request has been passed, use it
        return options.existingRequest;
      }

      const useCardRoute = options && options.forCard;
      if (options) {
        delete options.forCard;
      }

      const path = useCardRoute
        ? `${user.get("username")}/card.json`
        : `${user.get("username")}.json`;

      return ajax(userPath(path), { data: options });
    }).then((json: UserDetailsResponse) => {
      if (!isEmpty(json.user.stats)) {
        json.user.stats = User.groupStats(
          json.user.stats!.map((s) => {
            if (s.count) {
              s.count = parseInt(s.count as string, 10);
            }
            return UserActionStat.create(s as RestModelAttrs<UserActionStat>);
          })
        );
      }

      if (Object.hasOwn(json.user, "groups")) {
        json.user.visibleGroups = json.user.groups!.map((groupJson, index) => {
          // TODO(typescript-pending): RestModel.create drops required input fields;
          // remove when its factory retains profile group identity.
          const group = Group.create(groupJson) as Group &
            Pick<UserGroup, "id" | "name">;
          group.group_user = json.user.group_users?.[index];
          return group;
        });
        delete json.user.groups;
      }

      if (json.user.invited_by) {
        json.user.invited_by = User.create(
          json.user.invited_by as UserCreateAttrs
        );
      }

      if (!isEmpty(json.user.featured_user_badge_ids)) {
        // TODO(typescript-pending): UserBadge omits id and createFromJson's element type; remove when UserBadge is typed.
        const userBadgesMap: Record<number, UserBadge> = {};
        (
          UserBadge.createFromJson(json) as (UserBadge & { id: number })[]
        ).forEach((userBadge) => {
          userBadgesMap[userBadge.get("id") as number] = userBadge;
        });
        json.user.featured_user_badges = json.user.featured_user_badge_ids!.map(
          (id) => userBadgesMap[id]
        );
      }

      if (json.user.card_badge) {
        // TODO(typescript-pending): Badge.create returns its base wrapper; remove when Badge is typed.
        json.user.card_badge = Badge.create(
          json.user.card_badge
        ) as UserBadgeModel;
      }

      const timezone = json.user.timezone;
      delete json.user.timezone;

      user.setProperties(json.user);

      if (timezone) {
        user.user_option ||= {};
        user.user_option.timezone = timezone;
      }

      return user;
    });
  }

  findStaffInfo(): globalThis.Promise<void | null> {
    if (!User.currentProp("staff")) {
      return Promise.resolve(null);
    }
    return ajax(userPath(`${this.username_lower}/staff-info.json`)).then(
      (info) => {
        this.setProperties(info);
      }
    );
  }

  pickAvatar(
    upload_id: number | null,
    type: string,
    associated_account_id?: number
  ): globalThis.Promise<unknown> {
    return ajax(userPath(`${this.username_lower}/preferences/avatar/pick`), {
      type: "PUT",
      data: {
        upload_id,
        type,
        ...(associated_account_id && { associated_account_id }),
      },
    });
  }

  selectAvatar(avatarUrl: string): globalThis.Promise<unknown> {
    return ajax(userPath(`${this.username_lower}/preferences/avatar/select`), {
      type: "PUT",
      data: { url: avatarUrl },
    });
  }

  isAllowedToUploadAFile(type: string): boolean {
    const settingName = type === "image" ? "embedded_media" : "attachments";

    return (
      this.staff ||
      this.trust_level! > 0 ||
      (this.siteSettings[`newuser_max_${settingName}`] as number) > 0
    );
  }

  createInvite(
    email: string,
    group_ids?: number[],
    custom_message?: string
  ): globalThis.Promise<unknown> {
    return ajax("/invites", {
      type: "POST",
      data: { email, group_ids, custom_message },
    });
  }

  generateInviteLink(
    email?: string,
    group_ids?: number[],
    topic_id?: number
  ): globalThis.Promise<unknown> {
    return ajax("/invites", {
      type: "POST",
      data: { email, skip_email: true, group_ids, topic_id },
    });
  }

  delete(): globalThis.Promise<unknown> {
    if (this.can_delete_account) {
      return ajax(userPath(this.username + ".json"), {
        type: "DELETE",
        data: { context: window.location.pathname },
      });
    } else {
      return Promise.reject(i18n("user.delete_yourself_not_allowed"));
    }
  }

  updateNotificationLevel({
    level,
    expiringAt = null,
    actingUser = null,
  }: {
    level: "normal" | "mute" | "ignore";
    expiringAt?: string | null;
    actingUser?: User | null;
  }) {
    actingUser ||= User.current();

    return ajax(`${userPath(this.username)}/notification_level.json`, {
      type: "PUT",
      data: {
        notification_level: level,
        expiring_at: expiringAt,
        acting_user_id: actingUser!.id,
      },
    }).then(() => {
      if (!actingUser!.ignored_users) {
        actingUser!.ignored_users = [];
      }
      if (level === "normal" || level === "mute") {
        removeValueFromArray(actingUser!.ignored_users, this.username);
      } else if (level === "ignore") {
        addUniqueValueToArray(actingUser!.ignored_users, this.username);
      }
    });
  }

  dismissBanner(bannerKey: number) {
    this.set("dismissed_banner_key", bannerKey);
    ajax(userPath(this.username + ".json"), {
      type: "PUT",
      data: { dismissed_banner_key: bannerKey },
    });
  }

  checkEmail() {
    return ajax(userPath(`${this.username_lower}/emails.json`), {
      data: { context: window.location.pathname },
    }).then((result) => {
      if (result) {
        this.setProperties({
          email: result.email,
          secondary_emails: result.secondary_emails,
          unconfirmed_emails: result.unconfirmed_emails,
          associated_accounts: result.associated_accounts,
        });
      }
    });
  }

  summary(): globalThis.Promise<UserSummary> {
    const store = getOwnerWithFallback(this).lookup(
      "service:store"
    ) as StoreService;

    return ajax<{
      topics: RestModelAttrs<Topic>[];
      user_summary: Omit<UserSummary, "badges"> & {
        badges?: { badge_id: number; count: number }[];
      };
    }>(userPath(`${this.username_lower}/summary.json`)).then((json) => {
      const summary = json.user_summary;
      const topicMap: Record<number, Topic> = {};
      const badgeMap: Record<number, UserBadgeModel> = {};

      json.topics.forEach(
        (t) => (topicMap[t.id!] = store.createRecord("topic", t))
      );
      (Badge.createFromJson(json) as UserBadgeModel[]).forEach(
        (b) => (badgeMap[b.id] = b)
      );

      summary.topics = summary.topic_ids.map((id) => topicMap[id]);

      summary.replies.forEach((r) => {
        r.topic = topicMap[r.topic_id];
        r.url = r.topic.urlForPostNumber(r.post_number);
        r.createdAt = new Date(r.created_at);
      });

      summary.links.forEach((l) => {
        l.topic = topicMap[l.topic_id];
        l.post_url = l.topic.urlForPostNumber(l.post_number);
      });

      if (summary.badges) {
        (summary as UserSummary).badges = summary.badges.map((ub) => {
          const badge = badgeMap[ub.badge_id];
          badge.count = ub.count;
          return badge;
        });
      }

      if (summary.top_categories) {
        summary.top_categories.forEach((c) => {
          if (c.parent_category_id) {
            c.parentCategory = Category.findById(c.parent_category_id);
          }
        });
      }

      return summary as UserSummary;
    });
  }

  canManageGroup(group: Group) {
    return group.get("can_admin_group") || group.get("is_group_owner");
  }

  updateTextSizeCookie(newSize: string | null) {
    if (newSize) {
      const seq = this.get("user_option.text_size_seq");
      cookie(TEXT_SIZE_COOKIE_NAME, `${newSize}|${seq}`, {
        path: "/",
        expires: COOKIE_EXPIRY_DAYS,
      });
    } else {
      removeCookie(TEXT_SIZE_COOKIE_NAME, { path: "/" });
    }
  }

  resolvedTimezone() {
    deprecated(
      "user.resolvedTimezone() has been deprecated. Use user.user_option.timezone instead",
      {
        id: "discourse.user.resolved-timezone",
        since: "2.9.0.beta12",
      }
    );

    return this.user_option!.timezone;
  }

  calculateMutedIds(
    notificationLevel: number,
    id: number,
    type: "muted_category_ids"
  ): number[] {
    const muted_ids = this.get(type)!;
    if (notificationLevel === NotificationLevels.MUTED) {
      return uniqueItemsFromArray(muted_ids.concat(id));
    } else {
      return muted_ids.filter((existing_id) => existing_id !== id);
    }
  }

  setPrimaryGroup(primaryGroupId: number | null): globalThis.Promise<unknown> {
    return ajax(`/admin/users/${this.id}/primary_group`, {
      type: "PUT",
      data: { primary_group_id: primaryGroupId },
    });
  }

  enterDoNotDisturbFor(duration: number) {
    return ajax({
      url: "/do-not-disturb.json",
      type: "POST",
      data: { duration },
    }).then((response) => {
      return this.updateDoNotDisturbStatus(response.ends_at);
    });
  }

  leaveDoNotDisturb() {
    return ajax({
      url: "/do-not-disturb.json",
      type: "DELETE",
    }).then(() => {
      this.updateDoNotDisturbStatus(null);
    });
  }

  updateDoNotDisturbStatus(ends_at: string | null) {
    this.set("do_not_disturb_until", ends_at);
    this.appEvents.trigger("do-not-disturb:changed", this.do_not_disturb_until);
    (
      getOwner(this)!.lookup("service:notifications") as NotificationsService
    )._checkDoNotDisturb();
  }

  updateDraftProperties(
    properties: Partial<Pick<UserFields, "draft_count" | "pending_posts_count">>
  ) {
    this.setProperties(properties);
    this.appEvents.trigger("user-drafts:changed");
  }

  updateReviewableCount(count: number) {
    this.set("reviewable_count", count);
    this.appEvents.trigger("user-reviewable-count:changed", count);
  }

  isInDoNotDisturb(): boolean {
    if (this !== getOwner(this)!.lookup("service:current-user")) {
      throw "isInDoNotDisturb is only supported for currentUser";
    }

    // TODO(typescript-pending): NotificationsService's tracked state is untyped; remove when the service is typed.
    return (
      getOwner(this)!.lookup(
        "service:notifications"
      ) as NotificationsService & { isInDoNotDisturb: boolean }
    ).isInDoNotDisturb;
  }
}

User.reopenClass({
  /** Find a User for a given username. */
  findByUsername(username: string, options?: UserFindDetailsOptions) {
    const user = User.create({ username });
    return user.findDetails(options);
  },

  checkUsername(
    username?: string | null,
    email?: string | null,
    for_user_id?: number
  ) {
    return ajax(userPath("check_username"), {
      data: { username, email, for_user_id },
    });
  },

  checkEmail(email: string) {
    return ajax(userPath("check_email"), { data: { email } });
  },

  loadRecentSearches() {
    return ajax(`/u/recent-searches`);
  },

  resetRecentSearches() {
    return ajax(`/u/recent-searches`, { type: "DELETE" });
  },

  groupStats(stats: UserActionStat[]) {
    const responses = UserActionStat.create({
      count: 0,
      action_type: UserAction.TYPES.replies,
    });

    stats
      .filter((stat) => stat.isResponse)
      .forEach((stat) => {
        responses.set("count", responses.get("count") + stat.get("count"));
      });

    const result = trackedArray<UserActionStat>();
    result.push(...stats.filter((stat) => !stat.isResponse));

    let insertAt = 0;
    result.forEach((item, index) => {
      if (
        item.action_type === UserAction.TYPES.topics ||
        item.action_type === UserAction.TYPES.posts
      ) {
        insertAt = index + 1;
      }
    });
    if (responses.count > 0) {
      result.splice(insertAt, 0, responses);
    }
    return result;
  },

  async createAccount(attrs: UserAccountAttrs) {
    let data: RestPayload = {
      name: attrs.accountName,
      email: attrs.accountEmail,
      password: attrs.accountPassword,
      username: attrs.accountUsername,
      password_confirmation: attrs.accountPasswordConfirm,
      challenge: attrs.accountChallenge,
      user_fields: attrs.userFields,
      timezone: moment.tz.guess(),
    };

    if (attrs.inviteCode) {
      data.invite_code = attrs.inviteCode;
    }

    return applyBehaviorTransformer(
      "create-account",
      () =>
        ajax(userPath(), {
          data,
          type: "POST",
        }),
      { data }
    );
  },

  _saveTimezone(user: { username: string; user_option: UserOption }) {
    ajax(userPath(user.username + ".json"), {
      type: "PUT",
      dataType: "json",
      data: { timezone: user.user_option.timezone },
    });
  },

  create(
    this: typeof User & { _super: (attrs: UserCreateAttrs) => User },
    args?: UserCreateAttrs & RestPayload
  ) {
    args = args || {};
    this.deleteStatusTrackingFields(args);

    if (Object.hasOwn(args, "groups")) {
      args.visibleGroups = args.groups;
      delete args.groups;
    }

    return this._super(args);
  },

  deleteStatusTrackingFields(args: RestPayload) {
    // every user instance has to have it's own tracking fields
    // when creating a new user model
    // its _subscribersCount and _clearStatusTimerId fields
    // should be equal to 0 and null
    // here we makes sure that even if these fields
    // will be passed in args they won't be set anyway
    //
    // this is something that could be implemented by making these fields private,
    // but EmberObject doesn't support private fields
    if (args.hasOwnProperty("_subscribersCount")) {
      delete args._subscribersCount;
    }
    if (args.hasOwnProperty("_clearStatusTimerId")) {
      delete args._clearStatusTimerId;
    }
  },
});

/** Tracks live status updates and expiry for one user. */
class UserStatusManager {
  @service appEvents!: AppEventsService;

  user: User;
  _subscribersCount = 0;

  _clearStatusTimerId: Timer | null = null;

  constructor(user: User) {
    this.user = user;
    setOwner(this, getOwner(user)!);
  }

  /** Always call stopTrackingStatus() when done with a user. */
  trackStatus() {
    if (!this.user.id && !isTesting()) {
      // eslint-disable-next-line no-console
      console.warn(
        "It's impossible to track user status on a user model that doesn't have id. This user model won't be receiving live user status updates."
      );
    }

    if (this._subscribersCount === 0) {
      this.user.addObserver("status", this, "_statusChanged");

      this.appEvents.on("user-status:changed", this, this._updateStatus);

      if (this.user.status?.ends_at) {
        this._scheduleStatusClearing(this.user.status.ends_at);
      }
    }

    this._subscribersCount++;
  }

  stopTrackingStatus() {
    if (this._subscribersCount === 0) {
      return;
    }

    if (this._subscribersCount === 1) {
      // the last subscriber is unsubscribing
      this.user.removeObserver("status", this, "_statusChanged");
      this.appEvents.off("user-status:changed", this, this._updateStatus);
      this._unscheduleStatusClearing();
    }

    this._subscribersCount--;
  }

  isTrackingStatus() {
    return this._subscribersCount > 0;
  }

  _statusChanged() {
    this.user.trigger("status-changed", this.user);

    const status = this.user.status;
    if (status && status.ends_at) {
      this._scheduleStatusClearing(status.ends_at);
    } else {
      this._unscheduleStatusClearing();
    }
  }

  _scheduleStatusClearing(endsAt: string) {
    if (isTesting()) {
      return;
    }

    if (this._clearStatusTimerId) {
      this._unscheduleStatusClearing();
    }

    const utcNow = moment.utc();
    const remaining = moment.utc(endsAt).diff(utcNow, "milliseconds");
    this._clearStatusTimerId = discourseLater(
      this as UserStatusManager,
      "_autoClearStatus",
      remaining
    );
  }

  _unscheduleStatusClearing() {
    // Ember accepts null as a no-op at runtime, though cancel's declaration excludes it.
    cancel(this._clearStatusTimerId as Timer | undefined);
    this._clearStatusTimerId = null;
  }

  _autoClearStatus() {
    this.user.status = null;
  }

  _updateStatus(statuses: Record<number, UserStatus | null>) {
    if (statuses.hasOwnProperty(this.user.id)) {
      this.user.status = statuses[this.user.id];
    }
  }
}

if (typeof Discourse !== "undefined") {
  let warned = false;

  Object.defineProperty(Discourse, "User", {
    get() {
      if (!warned) {
        deprecated("Import the User class instead of using Discourse.User", {
          since: "2.4.0",
          id: "discourse.global.user",
        });
        warned = true;
      }
      return User;
    },
  });
}

/** Legacy globals supplied by the application, without introducing module imports. */
declare const moment: typeof import("moment");
declare const Discourse: object | undefined;
