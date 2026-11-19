import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import type User from "discourse/models/user";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18n } from "discourse-i18n";

/** A user as the list shows them. */
export interface SmallUserAttrs {
  /** The avatar template. */
  template?: string | null;

  /** The username, shown as the avatar title and used to open the user card. */
  username: string;

  /** A post to link the description to. */
  post_url?: string | null;

  /** The path of the user's profile. */
  url?: string;

  /** Whether the user is unknown, which shows a placeholder instead of an avatar. */
  unknown?: boolean;
}

/** The user fields that `smallUserAttrs` reads. */
interface SmallUserSource {
  avatar_template?: string | null;
  username: string;
  username_lower?: string;
  post_url?: string | null;
  unknown?: boolean;
}

interface DSmallUserListSignature {
  Args: {
    /** The users to show. */
    users: SmallUserAttrs[];

    /** Whether to add the current user when the list doesn't include them. */
    addSelf?: boolean;

    /** The translation key of a description shown after the avatars. */
    description?: string;

    /** The count passed to the description translation. */
    count?: number;

    /** Whether the list is shown. Defaults to `true`. */
    isVisible?: boolean;
  };

  Element: HTMLDivElement;
}

/**
 * Builds the attributes the list shows for a user. The `small-user-attrs` value
 * transformer can change them.
 *
 * @param user - The user to show.
 * @returns The attributes of the user.
 */
export function smallUserAttrs(user: SmallUserSource): SmallUserAttrs {
  const defaultAttrs = {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower),
    unknown: user.unknown,
  };

  return applyValueTransformer("small-user-attrs", defaultAttrs, {
    user,
  });
}

export default class DSmallUserList extends Component<DSmallUserListSignature> {
  @service declare currentUser: User | null;

  get users() {
    let users = this.args.users;
    const { currentUser } = this;
    if (
      this.args.addSelf &&
      currentUser &&
      !users.some((u) => u.username === currentUser.username)
    ) {
      users = users.concat(smallUserAttrs(currentUser));
    }
    return users;
  }

  get postUrl() {
    const user = this.users.find((u) => u.post_url);
    if (user) {
      return getURL(user.post_url);
    }
  }

  get shouldShow() {
    return this.users.length && (this.args.isVisible ?? true);
  }

  <template>
    <PluginOutlet @name="small-user-list-internal" @outletArgs={{this.args}}>
      <div
        class="small-user-list {{if this.shouldShow '--expanded'}}"
        ...attributes
      >
        <span
          aria-atomic="true"
          aria-live="polite"
          class="small-user-list-content"
          role="list"
        >
          {{#if this.shouldShow}}
            {{#each this.users key="username" as |user|}}
              {{#if user.unknown}}
                <div
                  class="unknown"
                  role="listitem"
                  title={{i18n "post.unknown_user"}}
                ></div>
              {{else}}
                <a
                  aria-hidden="false"
                  class="trigger-user-card"
                  data-user-card={{user.username}}
                  role="listitem"
                  title={{user.username}}
                >
                  {{dBoundAvatarTemplate user.template "tiny"}}
                </a>
              {{/if}}
            {{/each}}

            {{#if @description}}
              {{#if this.postUrl}}
                <a href={{this.postUrl}}>
                  <span class="list-description">
                    {{i18n @description count=@count}}
                  </span>
                </a>
              {{else}}
                <span class="list-description">
                  {{i18n @description count=@count}}
                </span>
              {{/if}}
            {{/if}}
          {{/if}}
        </span>
      </div>
    </PluginOutlet>
  </template>
}
