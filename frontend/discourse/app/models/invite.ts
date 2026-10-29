import EmberObject, { computed, set } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { isNone } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { userPath } from "discourse/lib/url";
import Topic, { type TopicFields } from "discourse/models/topic";
import User, { type UserCreateAttrs } from "discourse/models/user";

/** Detail fields are absent for other viewers; redeemed records use a different serializer. */
export interface InviteFields {
  id?: number;
  invite_key?: string;
  link?: string;
  description?: string | null;
  email?: string | null;
  domain?: string | null;
  emailed?: boolean;
  can_delete_invite?: boolean;
  max_redemptions_allowed?: number;
  redemption_count?: number;
  custom_message?: string | null;
  created_at?: string;
  updated_at?: string;
  expires_at?: string;
  expired?: boolean;
  grants_admin?: boolean;
  grants_moderator?: boolean;
  /** Server arrays do not supply firstObject; legacy client collections can. */
  topics?: InviteTopic[] & { firstObject?: InviteTopic };
  groups?: { id: number; name: string }[];
  redeemed_at?: string;
  invite_source?: "link" | "email";
  user?: User;
  destroyed?: boolean;
  reinvited?: boolean;
}

export type InviteTopic = Pick<
  TopicFields,
  "id" | "title" | "slug" | "fancy_title" | "posts_count"
>;

/** create wraps the raw redeemed user, but save only merges the response. */
export type InviteCreateAttrs<M = Invite> = Omit<Partial<M>, "user"> & {
  user?: UserCreateAttrs | User;
};

export interface InvitedFields {
  invites: Invite[];
  can_see_invite_details: boolean;
  counts: { pending: number; expired: number; redeemed: number; total: number };
}

export type Invited = EmberObject & InvitedFields;

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Invite extends InviteFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Invite extends EmberObject {
  static override create<C extends typeof EmberObject>(
    this: C,
    ...args: InviteCreateAttrs<InstanceType<C>>[]
  ): InstanceType<C> {
    const result = super.create(...args) as InstanceType<C> & Invite;
    if (result.user) {
      // TODO(typescript-pending): UserCreateAttrs requires an index signature; remove when User.create accepts model instances.
      result.user = User.create(result.user as UserCreateAttrs);
    }
    return result;
  }

  static async findInvitedBy(
    user?: User | null,
    filter?: string | null,
    search?: string | null,
    offset?: number
  ): Promise<Invited | undefined> {
    if (!user) {
      return;
    }

    const data: { filter?: string; search?: string; offset?: number } = {};
    if (!isNone(filter)) {
      data.filter = filter;
    }
    if (!isNone(search)) {
      data.search = search;
    }
    data.offset = offset || 0;

    // TODO(typescript-pending): ajax has no endpoint response types; remove the assertion when generic.
    const result = (await ajax(
      userPath(`${user.username_lower}/invited.json`),
      {
        data,
      }
    )) as Omit<InvitedFields, "invites"> & { invites: InviteCreateAttrs[] };

    result.invites = trackedArray(result.invites.map((i) => Invite.create(i)));

    return EmberObject.create(result as Invited);
  }

  static reinviteAll(): Promise<unknown> {
    return ajax("/invites/reinvite-all", { type: "POST" });
  }

  static destroyAllExpired(user: User): Promise<unknown> {
    return ajax("/invites/destroy-all-expired", {
      type: "POST",
      data: { username: user.username },
    });
  }

  @computed("topics.firstObject.id")
  get topicId() {
    return this.topics?.firstObject?.id;
  }

  set topicId(value: number | undefined) {
    set(this, "topics.firstObject.id", value);
  }

  @computed("topics.firstObject.title")
  get topicTitle() {
    return this.topics?.firstObject?.title;
  }

  set topicTitle(value: string | undefined) {
    set(this, "topics.firstObject.title", value);
  }

  @computed("invite_key")
  /** Requires a detail-visible pending invite with an invite key. */
  get shortKey() {
    return this.invite_key!.slice(0, 4) + "...";
  }

  @computed("groups")
  get groupIds() {
    return this.groups ? this.groups.map((group) => group.id) : [];
  }

  @computed("topics.firstObject")
  get topic() {
    return this.topics?.firstObject
      ? Topic.create(this.topics?.firstObject)
      : null;
  }

  @computed("email", "domain")
  get emailOrDomain() {
    return this.email || this.domain;
  }

  save(data: object) {
    const promise = this.id
      ? ajax(`/invites/${this.id}`, { type: "PUT", data })
      : ajax("/invites", { type: "POST", data });

    // TODO(typescript-pending): ajax has no endpoint response types; remove the callback annotation when generic.
    return promise.then((result: Partial<InviteFields>) =>
      this.setProperties(result)
    );
  }

  /** Deletes the invite remotely rather than scheduling Ember destruction. */
  override destroy(this: never, ...args: never[]): never;
  override destroy(): Promise<boolean>;
  override destroy(): Promise<boolean> {
    return ajax("/invites", {
      type: "DELETE",
      data: { id: this.id },
    }).then(() => this.set("destroyed", true));
  }

  reinvite(): Promise<boolean | void> {
    return ajax("/invites/reinvite", {
      type: "POST",
      data: { email: this.email },
    })
      .then(() => this.set("reinvited", true))
      .catch(popupAjaxError);
  }
}
