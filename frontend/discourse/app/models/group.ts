/* eslint-disable ember/no-observers */
/* eslint-disable prefer-const -- Preserve bindings in this types-only port. */
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedArray } from "@ember/reactive/collections";
import { isEmpty } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import { ajax } from "discourse/lib/ajax";
import {
  applyModelCallbacks,
  extraSavePropertiesFor,
} from "discourse/lib/model-extensions";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { applyValueTransformer } from "discourse/lib/transformer";
import Category, { type CategoryFields } from "discourse/models/category";
import GroupHistory from "discourse/models/group-history";
import RestModel, { type RestModelAttrs } from "discourse/models/rest";
import Site from "discourse/models/site";
import Topic, { type TopicBasicUser } from "discourse/models/topic";
import User, { type UserCreateAttrs } from "discourse/models/user";

/** Data shared by list, search and show payloads; new groups can omit server fields. */
export interface GroupFields {
  id?: number;
  name?: string;
  automatic?: boolean;
  display_name?: string | null;
  mentionable_level?: number | null;
  messageable_level?: number | null;
  visibility_level?: number;
  members_visibility_level?: number;
  primary_group?: boolean;
  title?: string | null;
  full_name?: string | null;
  grant_trust_level?: number | null;
  incoming_email?: string | null;
  has_messages?: boolean;
  flair_url?: string | null;
  flair_bg_color?: string | null;
  flair_color?: string | null;
  bio_raw?: string | null;
  bio_cooked?: string | null;
  bio_excerpt?: string | null;
  public_admission?: boolean;
  public_exit?: boolean;
  allow_membership_requests?: boolean;
  default_notification_level?: number;
  membership_request_template?: string | null;
  is_group_user?: boolean;
  is_group_owner?: boolean;
  is_group_owner_display?: boolean;
  can_see_members?: boolean;
  can_admin_group?: boolean;
  can_edit_group?: boolean;
  publish_read_state?: boolean;
  mentionable?: boolean;
  messageable?: boolean;
  automatic_membership_email_domains?: string | null;
  smtp_server?: string | null;
  smtp_port?: number | null;
  smtp_ssl_mode?: number;
  smtp_enabled?: boolean | null;
  smtp_updated_at?: string | null;
  smtp_updated_by?: TopicBasicUser | null;
  email_username?: string | null;
  email_password?: string | null;
  email_from_alias?: string | null;
  message_count?: number;
  allow_unknown_sender_topic_replies?: boolean;
  associated_group_ids?: number[];
  watching_category_ids?: number[];
  tracking_category_ids?: number[];
  watching_first_post_category_ids?: number[];
  regular_category_ids?: number[];
  muted_category_ids?: number[];
  watching_tags?: GroupTag[];
  tracking_tags?: GroupTag[];
  watching_first_post_tags?: GroupTag[];
  regular_tags?: GroupTag[];
  muted_tags?: GroupTag[];
  /** Attached during profile hydration, absent on ordinary group responses. */
  group_user?: {
    user_id: number;
    group_id: number;
    notification_level: number;
    owner?: boolean;
  };
  /** Editable client state, cleared after creation. */
  usernames?: string | string[] | null;
  ownerUsernames?: string | null;
  flair_type?: "icon" | "image";
  flair_icon?: string | null;
  flair_upload_id?: number | null;
}

/** Show payloads supply tag objects; the tag chooser also writes names. */
export type GroupTag = { id: number; name: string; slug: string } | string;

type NotificationLevel =
  | "muted"
  | "regular"
  | "watching"
  | "tracking"
  | "watching_first_post";

/** Empty selections use the API's category, tag and association sentinels. */
export type GroupSaveAttrs = Omit<
  GroupFields,
  | `${NotificationLevel}_tags`
  | `${NotificationLevel}_category_ids`
  | "associated_group_ids"
> & {
  name: string | undefined;
  primary_group: boolean;
  associated_group_ids?: (number | null)[];
  owner_usernames?: string | null;
} & Partial<Record<`${NotificationLevel}_tags`, string[]>> &
  Partial<Record<`${NotificationLevel}_category_ids`, (number | undefined)[]>>;

export interface GroupSaveOptions {
  update_existing_users?: boolean;
  [key: string]: unknown;
}

export interface GroupMemberParams {
  order?: string | null;
  asc?: boolean;
  filter?: string | null;
  limit?: number;
  offset?: number;
  requesters?: boolean;
}

export interface GroupMembersResponse {
  members: UserCreateAttrs[];
  owners: UserCreateAttrs[];
  meta: { total: number; limit: number; offset: number };
}

export interface GroupRequestersResponse {
  members: (UserCreateAttrs & {
    reason: string | null;
    requested_at: string;
  })[];
  meta: GroupMembersResponse["meta"];
}

/** Activity entries are EmberObjects, not Post instances. */
export interface GroupPostFields {
  id: number;
  created_at: string;
  topic_id: number;
  topic_title: string;
  topic_slug: string;
  topic_html_title: string;
  url: string;
  category_id: number | null;
  post_number: number;
  posts_count: number;
  post_type: number;
  user_id: number | null;
  username: string | null;
  name?: string | null;
  avatar_template: string | null;
  user_title: string | null;
  primary_group_name: string | null;
  excerpt: string | null;
  truncated?: true;
  user: User;
  topic: Topic;
  category?: Category;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Group extends GroupFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Group extends RestModel {
  static findAll(opts?: {
    term?: string;
    ignore_automatic?: boolean;
    include_everyone?: boolean;
  }): Promise<Group[]> {
    return ajax("/groups/search.json", { data: opts }).then(
      (groups: RestModelAttrs<Group>[]) => groups.map((g) => Group.create(g))
    );
  }

  static loadMembers(
    name: string | undefined,
    opts: GroupMemberParams & { requesters: true }
  ): Promise<GroupRequestersResponse>;

  static loadMembers(
    name: string | undefined,
    opts?: GroupMemberParams & { requesters?: false }
  ): Promise<GroupMembersResponse>;

  static loadMembers(
    name: string | undefined,
    opts?: GroupMemberParams
  ): Promise<GroupMembersResponse | GroupRequestersResponse>;

  static loadMembers(
    name: string | undefined,
    opts?: GroupMemberParams
  ): Promise<GroupMembersResponse | GroupRequestersResponse> {
    const data = applyValueTransformer("group-members-request", opts, { name });
    return ajax(`/groups/${name}/members.json`, { data });
  }

  static mentionable(name: string): Promise<{ mentionable: boolean }> {
    return ajax(`/groups/${name}/mentionable`);
  }

  static messageable(name: string): Promise<{ messageable: boolean }> {
    return ajax(`/groups/${name}/messageable`);
  }

  static checkName(name: string): Promise<{
    available?: boolean;
    suggestion?: string;
    is_developer?: boolean;
    errors?: string[];
  }> {
    return ajax("/groups/check-name", { data: { group_name: name } });
  }

  @autoTrackedArray members: User[] = [];
  @autoTrackedArray requesters: User[] = [];

  user_count = 0;

  limit: number | null = null;

  offset: number | null = null;
  request_count = 0;

  requestersLimit: number | null = null;

  requestersOffset: number | null = null;

  @dependentKeyCompat
  get watchingCategories() {
    if (
      this.site.lazy_load_categories &&
      this.watching_category_ids &&
      !Category.hasAsyncFoundAll(this.watching_category_ids)
    ) {
      Category.asyncFindByIds(this.watching_category_ids).then(() =>
        this.notifyPropertyChange("watching_category_ids")
      );
    }

    return Category.findByIds(this.get("watching_category_ids"));
  }

  set watchingCategories(categories: Category[]) {
    this.set(
      "watching_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get trackingCategories() {
    if (
      this.site.lazy_load_categories &&
      this.tracking_category_ids &&
      !Category.hasAsyncFoundAll(this.tracking_category_ids)
    ) {
      Category.asyncFindByIds(this.tracking_category_ids).then(() =>
        this.notifyPropertyChange("tracking_category_ids")
      );
    }

    return Category.findByIds(this.get("tracking_category_ids"));
  }

  set trackingCategories(categories: Category[]) {
    this.set(
      "tracking_category_ids",
      categories.map((c) => c.id)
    );
  }

  @dependentKeyCompat
  get watchingFirstPostCategories() {
    if (
      this.site.lazy_load_categories &&
      this.watching_first_post_category_ids &&
      !Category.hasAsyncFoundAll(this.watching_first_post_category_ids)
    ) {
      Category.asyncFindByIds(this.watching_first_post_category_ids).then(() =>
        this.notifyPropertyChange("watching_first_post_category_ids")
      );
    }

    return Category.findByIds(this.get("watching_first_post_category_ids"));
  }

  set watchingFirstPostCategories(categories: Category[]) {
    this.set(
      "watching_first_post_category_ids",
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

  @computed("mentionable_level")
  get canEveryoneMention() {
    return this.mentionable_level === 99;
  }

  @computed("automatic_membership_email_domains")
  get emailDomains(): string {
    return isEmpty(this.automatic_membership_email_domains)
      ? ""
      : this.automatic_membership_email_domains!;
  }

  @computed("associated_group_ids")
  get associatedGroupIds(): number[] {
    return isEmpty(this.associated_group_ids) ? [] : this.associated_group_ids!;
  }

  @computed("automatic")
  get type(): "automatic" | "custom" {
    return this.automatic ? "automatic" : "custom";
  }

  @computed("display_name", "name")
  get displayName() {
    return this.display_name || this.name;
  }

  @computed("flair_bg_color")
  get flairBackgroundHexColor() {
    return this.flair_bg_color
      ? this.flair_bg_color.replace(new RegExp("[^0-9a-fA-F]", "g"), "")
      : null;
  }

  @computed("flair_color")
  get flairHexColor() {
    return this.flair_color
      ? this.flair_color.replace(new RegExp("[^0-9a-fA-F]", "g"), "")
      : null;
  }

  @computed("visibility_level")
  get isPrivate() {
    return this.visibility_level! > 1;
  }

  async reloadMembers(
    params?: GroupMemberParams,
    refresh?: boolean
  ): Promise<void> {
    if (isEmpty(this.name) || !this.can_see_members) {
      return;
    }

    if (refresh) {
      this.setProperties({ limit: null, offset: null, members: [] });
    }

    params = { offset: (this.offset || 0) + (this.limit || 0), ...params };

    // This path assumes owners are present even if params overrides requesters.
    const response = (await Group.loadMembers(
      this.name,
      params
    )) as GroupMembersResponse;
    const ownerIds = new Set();
    response.owners.forEach((owner) => ownerIds.add(owner.id));

    this.members.push(
      ...response.members.map((member) => {
        member.owner = ownerIds.has(member.id);
        member.primary = member.primary_group_name === this.name;
        return User.create(member);
      })
    );

    this.setProperties({
      user_count: response.meta.total,
      limit: response.meta.limit,
      offset: response.meta.offset,
    });
  }

  async findRequesters(
    params?: GroupMemberParams,
    refresh?: boolean
  ): Promise<void> {
    if (isEmpty(this.name) || !this.can_see_members) {
      throw new Error();
    }

    if (refresh) {
      this.setProperties({
        requesters: [],
        requestersOffset: null,
        requestersLimit: null,
      });
    }

    params = {
      offset: (this.requestersOffset || 0) + (this.requestersLimit || 0),
      requesters: true,
      ...params,
    };

    const result = await Group.loadMembers(this.name, params);
    this.requesters.push(...result.members.map((m) => User.create(m)));

    this.setProperties({
      request_count: result.meta.total,
      requestersLimit: result.meta.limit,
      requestersOffset: result.meta.offset,
    });
  }

  async removeOwner(member: Pick<User, "id">): Promise<void> {
    await ajax(`/admin/groups/${this.id}/owners.json`, {
      type: "DELETE",
      data: { user_id: member.id },
    });
    await this.reloadMembers({}, true);
  }

  async removeMember(
    member: Pick<User, "id">,
    params?: GroupMemberParams
  ): Promise<void> {
    await ajax(`/groups/${this.id}/members.json`, {
      type: "DELETE",
      data: { user_id: member.id },
    });
    await this.reloadMembers(params, true);
  }

  async leave() {
    await ajax(`/groups/${this.id}/leave.json`, {
      type: "DELETE",
    });
    this.set("can_see_members", this.members_visibility_level! < 2);
    await this.reloadMembers({}, true);
  }

  async addMembers(
    usernames: string | string[],
    filter?: boolean,
    notifyUsers?: boolean,
    emails: string | string[] = []
  ): Promise<void> {
    const response: { usernames: string[] } = await ajax(
      `/groups/${this.id}/members.json`,
      {
        type: "PUT",
        data: { usernames, emails, notify_users: notifyUsers },
      }
    );
    if (filter) {
      await this._filterMembers(response.usernames);
    } else {
      await this.reloadMembers();
    }
  }

  async join() {
    await ajax(`/groups/${this.id}/join.json`, {
      type: "PUT",
    });
    await this.reloadMembers({}, true);
  }

  async addOwners(
    usernames: string | string[],
    filter?: boolean,
    notifyUsers?: boolean
  ): Promise<void> {
    const response: { usernames: string[] } = await ajax(
      `/groups/${this.id}/owners.json`,
      {
        type: "PUT",
        data: { usernames, notify_users: notifyUsers },
      }
    );

    if (filter) {
      await this._filterMembers(response.usernames);
    } else {
      await this.reloadMembers({}, true);
    }
  }

  asJSON(): GroupSaveAttrs {
    const attrs: GroupSaveAttrs = {
      name: this.name,
      mentionable_level: this.mentionable_level,
      messageable_level: this.messageable_level,
      visibility_level: this.visibility_level,
      members_visibility_level: this.members_visibility_level,
      automatic_membership_email_domains: this.emailDomains,
      title: this.title,
      primary_group: !!this.primary_group,
      grant_trust_level: this.grant_trust_level,
      incoming_email: this.incoming_email,
      smtp_server: this.smtp_server,
      smtp_port: this.smtp_port,
      smtp_ssl_mode: this.smtp_ssl_mode,
      smtp_enabled: this.smtp_enabled,
      email_username: this.email_username,
      email_from_alias: this.email_from_alias,
      email_password: this.email_password,
      flair_icon: null as string | null,
      flair_upload_id: null as number | null,
      flair_bg_color: this.flairBackgroundHexColor,
      flair_color: this.flairHexColor,
      bio_raw: this.bio_raw,
      public_admission: this.public_admission,
      public_exit: this.public_exit,
      allow_membership_requests: this.allow_membership_requests,
      full_name: this.full_name,
      default_notification_level: this.default_notification_level,
      membership_request_template: this.membership_request_template,
      publish_read_state: this.publish_read_state,
      allow_unknown_sender_topic_replies:
        this.allow_unknown_sender_topic_replies,
    };

    ["muted", "regular", "watching", "tracking", "watching_first_post"].forEach(
      (s) => {
        let prop = (
          s === "watching_first_post"
            ? "watchingFirstPostCategories"
            : s + "Categories"
        ) as
          | "watchingFirstPostCategories"
          | `${Exclude<NotificationLevel, "watching_first_post">}Categories`;

        let categories = this.get(prop);

        if (categories) {
          attrs[(s + "_category_ids") as `${NotificationLevel}_category_ids`] =
            categories.length > 0 ? categories.map((c) => c.get("id")) : [-1];
        }

        let tags = this.get((s + "_tags") as `${NotificationLevel}_tags`);

        if (tags) {
          attrs[(s + "_tags") as `${NotificationLevel}_tags`] =
            tags.length > 0
              ? tags.map((t) => (typeof t === "object" ? t.name : t))
              : [""];
        }
      }
    );

    let agIds = this.associated_group_ids;
    if (agIds) {
      attrs["associated_group_ids"] = agIds.length ? agIds : [null];
    }

    if (this.flair_type === "icon") {
      attrs["flair_icon"] = this.flair_icon;
    } else if (this.flair_type === "image") {
      attrs["flair_upload_id"] = this.flair_upload_id;
    }

    if (!this.id) {
      attrs["usernames"] = this.usernames;
      attrs["owner_usernames"] = this.ownerUsernames;
    }

    return { ...attrs, ...extraSavePropertiesFor("group", this) };
  }

  /**
   * Creates the group on the server.
   *
   * @returns The created group, as the server serializes it.
   */
  async create(): Promise<GroupFields & { id: number; name: string }> {
    await applyModelCallbacks("group", "beforeCreate", this);

    const response: {
      basic_group: GroupFields & { id: number; name: string };
    } = await ajax("/admin/groups", {
      type: "POST",
      data: { group: this.asJSON() },
    });

    this.setProperties({
      id: response.basic_group.id,
      usernames: null,
      ownerUsernames: null,
    });

    await this.reloadMembers();
    await applyModelCallbacks("group", "afterCreate", this, response);
    return response.basic_group;
  }

  /** Preserves RestModel compatibility; redirects can resolve without a response body. */
  save(this: never, ...args: never[]): never;
  save(opts?: GroupSaveOptions): Promise<{ success: string } | undefined>;
  async save(
    opts: GroupSaveOptions = {}
  ): Promise<{ success: string } | undefined> {
    await applyModelCallbacks("group", "beforeUpdate", this, opts);

    const result = await ajax(`/groups/${this.id}`, {
      type: "PUT",
      data: { group: this.asJSON(), ...opts },
    });

    await applyModelCallbacks("group", "afterUpdate", this, result);
    return result;
  }

  /** Preserves EmberObject compatibility without offering synchronous destruction. */
  destroy(this: never, ...args: never[]): never;
  destroy(): Promise<{ success: string } | undefined>;
  async destroy(): Promise<{ success: string } | undefined> {
    if (!this.id) {
      return;
    }

    await applyModelCallbacks("group", "beforeDestroy", this);
    const result = await ajax(`/admin/groups/${this.id}`, { type: "DELETE" });
    await applyModelCallbacks("group", "afterDestroy", this, result);
    return result;
  }

  findLogs(
    offset?: number,
    filters?: {
      action?: string | null;
      acting_user?: string | null;
      target_user?: string | null;
      subject?: string | null;
    }
  ): Promise<EmberObject & { logs: GroupHistory[]; all_loaded: boolean }> {
    return ajax(`/groups/${this.name}/logs.json`, {
      data: { offset, filters },
    }).then(
      (results: {
        logs: RestModelAttrs<GroupHistory>[];
        all_loaded: boolean;
      }) => {
        // EmberObject.create's inferred keys exclude these payload-only properties.
        return EmberObject.create({
          logs: trackedArray(
            results["logs"].map((log) => GroupHistory.create(log))
          ),
          all_loaded: results["all_loaded"],
        } as object) as EmberObject & {
          logs: GroupHistory[];
          all_loaded: boolean;
        };
      }
    );
  }

  async findPosts(opts?: {
    type?: "posts" | "mentions";
    categoryId?: number | string | null;
    before?: string;
  }): Promise<(EmberObject & GroupPostFields)[]> {
    opts = opts || {};
    const type = opts.type || "posts";
    const data: { before?: string; category_id?: number } = {};

    if (opts.before) {
      data.before = opts.before;
    }

    if (opts.categoryId) {
      // parseInt also coerces numeric category IDs at runtime.
      data.category_id = parseInt(opts.categoryId as string, 10);
    }

    const result: {
      categories?: CategoryFields[];
      posts: (Omit<GroupPostFields, "user" | "topic"> & {
        user?: UserCreateAttrs | null;
        topic: RestModelAttrs<Topic> | Topic;
      })[];
    } = await ajax(`/groups/${this.name}/${type}.json`, { data });

    result.categories?.forEach((category) => {
      Site.current().updateCategory(category);
    });

    return trackedArray(
      result.posts.map((p) => {
        // TODO(typescript-pending): User.create inherits RestModel's null normalization;
        // remove when User's factory input includes null.
        p.user = User.create(p.user as UserCreateAttrs);
        p.topic = Topic.create(p.topic as RestModelAttrs<Topic>);
        p.category = Category.findById(p.category_id);
        // Both relationships are hydrated above; the factory only infers base keys.
        return EmberObject.create(p as object) as EmberObject & GroupPostFields;
      })
    );
  }

  setNotification(
    notification_level: number,
    userId: number
  ): Promise<{ success: string }> {
    this.set("group_user.notification_level", notification_level);
    return ajax(`/groups/${this.name}/notifications`, {
      data: { notification_level, user_id: userId },
      type: "POST",
    });
  }

  requestMembership(
    reason: string
  ): Promise<{ success: string; relative_url: string }> {
    return ajax(`/groups/${this.name}/request_membership.json`, {
      type: "POST",
      data: { reason },
    });
  }

  _filterMembers(usernames: string[]): Promise<void> {
    return this.reloadMembers({ filter: usernames.join(",") });
  }

  @observes("isPrivate", "canEveryoneMention")
  _updateAllowMembershipRequests() {
    if (this.isPrivate || !this.canEveryoneMention) {
      this.set("allow_membership_requests", false);
    }
  }
}
