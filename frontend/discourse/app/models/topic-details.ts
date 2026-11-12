import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import {
  removeAllowedTopicGroup,
  removeAllowedTopicUser,
  updateTopicNotificationLevel,
} from "discourse/data/builders/topic-details";
import { normalizeTopicDetailsPayload } from "discourse/data/normalize";
import RestCompatModel from "discourse/data/rest-compat";
import { TopicDetailsSchema } from "discourse/data/schemas/topic-details";
import {
  defineFieldForwarders,
  type WarpResource,
  type WarpResourceId,
  warpStore,
} from "discourse/data/warp-rest-model";
import type { RestModelStoreAttrs } from "discourse/models/rest";
import type { default as Topic, TopicBasicUser } from "discourse/models/topic";
import User from "discourse/models/user";
import type WarpStore from "discourse/services/warp-store";

/** A TopicPostCountSerializer row, before loading wraps it. */
export interface TopicDetailsParticipantPayload extends TopicBasicUser {
  post_count: number;
  primary_group_name: string | null;
  flair_name: string | null;
  flair_url: string | null;
  flair_color: string | null;
  flair_bg_color: string | null;
  flair_group_id: number | null;
  /** Sent only when true. */
  admin?: true;
  moderator?: true;
  trust_level: number;
}

/** A TopicLinkSerializer row; the topic map sends only clicked links. */
export interface TopicDetailsLinkPayload {
  url: string;
  title: string | null;
  internal: boolean;
  attachment: boolean;
  reflection: boolean | null;
  clicks: number;
  /** Sent only when the link has a user. */
  user_id?: number;
  domain: string;
  /** The public-suffix lookup can return null for hosts it cannot split. */
  root_domain: string | null;
}

/** A BasicGroupSerializer row; nullability follows the `groups` columns. */
export interface TopicDetailsAllowedGroupPayload {
  id: number;
  name: string;
  automatic: boolean;
  /** Automatic groups only; unknown automatic ids have no name. */
  display_name?: string | null;
  /** Only when the viewer can see members. */
  user_count?: number;
  mentionable_level: number | null;
  messageable_level: number | null;
  visibility_level: number;
  primary_group: boolean;
  title: string | null;
  grant_trust_level: number | null;
  /** Staff only. */
  incoming_email?: string | null;
  /** Staff, or viewers who can see the group's messages. */
  has_messages?: boolean;
  flair_url: string | null;
  flair_bg_color: string | null;
  flair_color: string | null;
  /** Staff, or group owners. */
  bio_raw?: string | null;
  bio_cooked: string | null;
  bio_excerpt: string | null;
  public_admission: boolean;
  public_exit: boolean;
  allow_membership_requests: boolean;
  full_name: string | null;
  default_notification_level: number;
  membership_request_template: string | null;
  /** Only when the serializer is given the viewer's group ids. */
  is_group_user?: boolean;
  /** Only when the serializer is given the viewer's owned group ids. */
  is_group_owner?: boolean;
  members_visibility_level: number;
  can_see_members: boolean;
  /** Permission flags are included only when granted. */
  can_admin_group?: true;
  can_edit_group?: true;
  publish_read_state: boolean;
}

/**
 * TopicViewDetailsSerializer fields, all optional because a topic creates its details before they load.
 * Permissions are sent only when granted, except `can_edit`; client code may also set them to false.
 */
export interface TopicDetailsFields {
  can_edit?: boolean;
  can_move_posts?: boolean;
  can_delete?: boolean;
  can_permanently_delete?: boolean;
  can_recover?: boolean;
  can_remove_allowed_users?: boolean;
  can_invite_to?: boolean;
  can_invite_via_email?: boolean;
  can_create_post?: boolean;
  can_reply_as_new_topic?: boolean;
  can_flag_topic?: boolean;
  can_convert_topic?: boolean;
  can_review_topic?: boolean;
  can_edit_tags?: boolean;
  can_publish_page?: boolean;
  can_close_topic?: boolean;
  can_archive_topic?: boolean;
  can_split_merge_topic?: boolean;
  can_edit_staff_notes?: boolean;
  can_toggle_topic_visibility?: boolean;
  can_pin_unpin_topic?: boolean;
  can_banner_topic?: boolean;
  can_moderate_category?: boolean;
  /** The user allowed to remove themselves from the topic, not a permission flag. */
  can_remove_self_id?: number;
  notification_level?: number;
  /** Sent only when the viewer has a topic user row. */
  notifications_reason_id?: number | null;
  /** Null when the topic has no user. */
  created_by?: TopicBasicUser | null;
  /** Optimistic posting assigns the current user. */
  last_poster?: TopicBasicUser | User | null;
  /** Sent only when the topic has clicked links. */
  links?: TopicDetailsLinkPayload[];
  /** Personal message recipients; loading wraps them in User. */
  allowed_users?: (User | TopicBasicUser)[];
  /** Loading wraps each row in an EmberObject that points back at the topic. */
  participants?: (TopicDetailsParticipantPayload & { topic?: Topic | null })[];
  /** Personal message groups. */
  allowed_groups?: TopicDetailsAllowedGroupPayload[];
}

/** Details are identified by their parent topic, including before it loads. */
export type TopicDetailsCreateAttrs<M = TopicDetails> = Partial<Omit<M, "id">> &
  RestModelStoreAttrs & {
    id?: WarpResourceId | null;
  };

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface TopicDetails extends TopicDetailsFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class TopicDetails extends RestCompatModel {
  static override type = "topic-details";

  /**
   * `store.createRecord("topicDetails", { id, topic, ...attrs })` entry point.
   * Extras (e.g. tests doing `topic.details = { allowed_users: [...] }`) land
   * in `#draft` until `updateFromJson` populates the cache record.
   */
  static override create<
    C extends abstract new (...args: never[]) => RestCompatModel,
  >(
    this: C,
    attrs?: TopicDetailsCreateAttrs<InstanceType<C>> | InstanceType<C>
  ): InstanceType<C>;

  static override create<C extends typeof RestCompatModel>(
    this: C,
    attrs?: TopicDetailsCreateAttrs<InstanceType<C>> | InstanceType<C>
  ): InstanceType<C>;

  static override create({ id, topic, ...rest }: TopicDetailsCreateAttrs = {}) {
    const td = new this(id);
    if (topic !== undefined) {
      td.topic = topic;
    }
    if (Object.keys(rest).length > 0) {
      td.#draft = rest;
    }
    return td;
  }

  /** Becomes true after updateFromJson pushes details for a resolved topic id. */
  @tracked loaded = false;

  /** Assigned by create or restored with the parent topic back-reference. */
  topic: Topic | null = null;

  #topicId: string | null;
  #cachedRecord: WarpResource | undefined;
  #draft: WarpResource = {};

  constructor(topicId?: WarpResourceId | null) {
    super();
    this.#topicId = topicId == null ? null : String(topicId);
  }

  // `#topicId in this` is only true once `super()` has returned and our own
  // fields and private methods are installed. The base constructor fires plugin
  // `init` callbacks, which can reach `id` / `__resource` before that — and
  // touching anything private that early throws. The check has to be inline:
  // hiding it behind a private helper would trip the same trap.
  override get id() {
    return #topicId in this ? this.#effectiveTopicId() : null;
  }

  // Falls back to `#draft` so attrs set via `create({...})` (or assigned
  // before `updateFromJson`) are readable/writable. The cached record is
  // memoized (identity is stable per type + id): this getter backs every field
  // forwarder, and topic templates read those on every render.
  override get __resource(): WarpResource | undefined {
    // See `id` — nothing private is reachable until `super()` has returned.
    if (!(#topicId in this)) {
      return undefined;
    }
    if (this.#cachedRecord) {
      return this.#cachedRecord;
    }
    const id = this.#effectiveTopicId();
    if (id != null) {
      const cached = warpStore().peekRecord({
        type: "topic-details",
        id,
      });
      if (cached) {
        return (this.#cachedRecord = cached as WarpResource);
      }
    }
    return this.#draft;
  }

  /**
   * Wraps user/participant sideloads to match legacy RestModel behavior so
   * `instanceof User` and EmberObject methods keep working.
   */
  override updateFromJson(
    details: TopicDetailsFields | null | undefined
  ): undefined {
    const id = this.#effectiveTopicId();
    if (id == null || !details) {
      return;
    }
    const wrapped = { ...details };
    // Inviting a user appends here in place; inviting a group reloads the
    // topic instead, so `allowed_groups` needs no equivalent.
    if (details.allowed_users) {
      wrapped.allowed_users = trackedArray(
        details.allowed_users.map((u) => User.create(u))
      );
    }
    if (details.participants) {
      const topic = this.topic;
      wrapped.participants = details.participants.map(
        (p) =>
          EmberObject.create({
            ...p,
            topic,
          } as Partial<EmberObject>) as EmberObject &
            TopicDetailsParticipantPayload & { topic: Topic | null }
      );
    }
    const store = warpStore();
    store.push(normalizeTopicDetailsPayload({ topicId: id, details: wrapped }));
    this._applyExtraAttributes(id);
    this.loaded = true;
  }

  updateNotifications(level: number) {
    const store = warpStore();
    const id = this.#effectiveTopicId();
    return store
      .request(
        updateTopicNotificationLevel(id, level) as Parameters<
          WarpStore["request"]
        >[0]
      )
      .then(() => {
        this.notification_level = level;
        this.notifications_reason_id = null;
      });
  }

  async removeAllowedGroup(
    group: NonNullable<TopicDetailsFields["allowed_groups"]>[number]
  ) {
    const store = warpStore();
    await store.request(
      removeAllowedTopicGroup(
        this.#effectiveTopicId(),
        group.name
      ) as Parameters<WarpStore["request"]>[0]
    );
    this.allowed_groups = this.allowed_groups!.filter(
      (g) => g.name !== group.name
    );
  }

  async removeAllowedUser(user: User | TopicBasicUser) {
    const username = user.username ?? (user as User).get?.("username");
    const store = warpStore();
    await store.request(
      removeAllowedTopicUser(this.#effectiveTopicId(), username) as Parameters<
        WarpStore["request"]
      >[0]
    );
    this.allowed_users = trackedArray(
      this.allowed_users!.filter((u) => u.username !== username)
    );
  }

  // Topic's `_details` field initializer runs before Topic.id is assigned, so
  // back-fill lazily from `this.topic.id` on first access.
  #effectiveTopicId() {
    if (this.#topicId == null && this.topic?.id != null) {
      this.#topicId = String(this.topic.id);
    }
    return this.#topicId;
  }
}

defineFieldForwarders(TopicDetails, TopicDetailsSchema);
