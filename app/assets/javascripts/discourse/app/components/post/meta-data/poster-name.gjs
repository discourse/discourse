import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { and, or } from "truth-helpers";
import GroupLink from "discourse/components/group-link";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserBadge from "discourse/components/user-badge";
import UserLink from "discourse/components/user-link";
import UserStatusMessage from "discourse/components/user-status-message";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import helperFn from "discourse/helpers/helper-fn";
import lazyHash from "discourse/helpers/lazy-hash";
import userPrioritizedName from "discourse/helpers/user-prioritized-name";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import { formatUsername } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class PostMetaDataPosterName extends Component {
  @service siteSettings;
  @service userStatus;

  showNameAndGroup = true;
  showGlyph = true;

  trackUserStatus = helperFn(({ user }, on) => {
    if (!this.userStatus.isEnabled) {
      return;
    }

    user?.statusManager?.trackStatus();

    on.cleanup(() => {
      user?.statusManager?.stopTrackingStatus();
    });
  });

  get suppressSimilarName() {
    return applyValueTransformer(
      "post-meta-data-poster-name-suppress-similar-name",
      true,
      { post: this.args.post, user: this.user, name: this.name }
    );
  }

  get name() {
    return userPrioritizedName(this.user);
  }

  get nameFirst() {
    return this.name === this.user.name;
  }

  get primaryGroupHref() {
    return getURL(`/g/${this.user.primary_group_name}`);
  }

  get shouldDisplaySecondName() {
    return (
      this.user.name &&
      this.siteSettings.display_name_on_posts &&
      this.#sanitizeName(this.user.name) !==
        this.#sanitizeName(this.user.username)
    );
  }

  get user() {
    return this.args.post.user;
  }

  get userTitle() {
    return applyValueTransformer("poster-name-user-title", this.user.title, {
      post: this.args.post,
      user: this.user,
    });
  }

  get titleClassNames() {
    const classNames = [this.userTitle];

    if (this.args.post.title_is_group && this.user.primary_group_name) {
      classNames.push(this.user.primary_group_name);
    }

    return classNames.map(
      (className) =>
        `user-title--${className.replace(/\s+/g, "-").toLowerCase()}`
    );
  }

  get additionalClasses() {
    return applyValueTransformer("poster-name-class", [], {
      post: this.args.post,
      user: this.user,
    });
  }

  get shouldShowUserStatus() {
    return this.userStatus.isEnabled && this.user.status;
  }

  @bind
  withBadgeDescription(badge) {
    // Alter the badge description to show that the badge was granted for this post.
    badge.description = i18n("post.badge_granted_tooltip", {
      username: this.args.post.username,
      badge_name: badge.name,
    });

    return badge;
  }

  #sanitizeName(name) {
    return this.suppressSimilarName
      ? name.toLowerCase().replace(/[\s._-]/g, "")
      : name;
  }

  <template>
    {{this.trackUserStatus user=this.user}}
    <div class="names trigger-user-card">
      <PluginOutlet
        @name="post-meta-data-poster-name"
        @outletArgs={{lazyHash post=@post user=this.user}}
      >
        <span
          class={{concatClass
            "first"
            (if this.nameFirst "full-name" "username")
            (if @post.staff "staff")
            (if @post.admin "admin")
            (if @post.moderator "moderator")
            (if @post.group_moderator "category-moderator")
            (if @post.new_user "new-user")
            (if
              @post.primary_group_name
              (concat "group--" @post.primary_group_name)
            )
            this.additionalClasses
          }}
        >
          {{! use the position argument to choose between the first and second name if needed}}
          <PluginOutlet
            @name="post-meta-data-poster-name-user-link"
            @outletArgs={{lazyHash
              position="first"
              name=this.name
              post=@post
              user=this.user
            }}
          >
            <UserLink @user={{@user}}>
              {{this.name}}
              {{#if this.showGlyph}}
                {{#if (or @post.moderator @post.group_moderator)}}
                  {{icon
                    "shield-halved"
                    translatedTitle=(i18n "user.moderator_tooltip")
                  }}
                {{/if}}
              {{/if}}
            </UserLink>
          </PluginOutlet>
        </span>

        {{#if this.showNameAndGroup}}
          {{#if this.shouldDisplaySecondName}}
            <span
              class={{concatClass
                "second"
                (if this.nameFirst "username" "full-name")
              }}
            >
              {{! use the position argument to choose between the first and second name if needed}}
              <PluginOutlet
                @name="post-meta-data-poster-name-user-link"
                @outletArgs={{lazyHash
                  position="second"
                  name=this.name
                  post=@post
                  user=this.user
                }}
              >
                <UserLink @user={{@post}}>
                  {{#if this.nameFirst}}
                    {{formatUsername @post.username}}
                  {{else}}
                    {{@post.name}}
                  {{/if}}
                </UserLink>
              </PluginOutlet>
            </span>
          {{/if}}

          {{#if this.userTitle}}
            <span class={{concatClass "user-title" this.titleClassNames}}>
              {{#if (and @post.primary_group_name @post.title_is_group)}}
                <GroupLink
                  @name={{@post.primary_group_name}}
                  @href={{this.primaryGroupHref}}
                >
                  {{this.userTitle}}
                </GroupLink>
              {{else}}
                {{this.userTitle}}
              {{/if}}
            </span>
          {{/if}}

          {{#if this.shouldShowUserStatus}}
            <span class="user-status-message-wrap">
              <UserStatusMessage @status={{this.user.status}} />
            </span>
          {{/if}}

          {{#if @post.badgesGranted}}
            <span class="user-badge-buttons">
              {{#each @post.badgesGranted key="id" as |badge|}}
                <span class={{concat "user-badge-button-" badge.slug}}>
                  <UserBadge
                    @badge={{this.withBadgeDescription badge}}
                    @user={{@post.user}}
                    @showName={{false}}
                  />
                </span>
              {{/each}}
            </span>
          {{/if}}
        {{/if}}
      </PluginOutlet>
    </div>
  </template>
}
