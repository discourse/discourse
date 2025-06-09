import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { and, or } from "truth-helpers";
import GroupLink from "discourse/components/group-link";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserBadge from "discourse/components/user-badge";
import UserLink from "discourse/components/user-link";
import UserStatusMessage from "discourse/components/user-status-message";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
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

  constructor() {
    super(...arguments);
    this.#trackUserStatus();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#stopTrackingUserStatus();
  }

  get suppressSimilarName() {
    return applyValueTransformer(
      "post-meta-data-poster-name-suppress-similar-name",
      true,
      { post: this.args.post, name: this.name }
    );
  }

  get name() {
    return userPrioritizedName(this.args.post);
  }

  get nameFirst() {
    return this.name === this.args.post.name;
  }

  get primaryGroupHref() {
    return getURL(`/g/${this.args.post.primary_group_name}`);
  }

  get shouldDisplaySecondName() {
    return (
      this.args.post.name &&
      this.siteSettings.display_name_on_posts &&
      this.#sanitizeName(this.args.post.name) !==
        this.#sanitizeName(this.args.post.username)
    );
  }

  get user() {
    // TODO where does user comes from?
    return this.args.post.user;
  }

  get titleClassNames() {
    const classNames = [this.args.post.user_title];

    if (this.args.post.title_is_group && this.args.post.primary_group_name) {
      classNames.push(this.args.post.primary_group_name);
    }

    return classNames.map(
      (className) =>
        `user-title--${className.replace(/\s+/g, "-").toLowerCase()}`
    );
  }

  get additionalClasses() {
    return applyValueTransformer("poster-name-class", [], {
      user: this.user,
    });
  }

  @bind
  refreshUserStatus() {
    this.#stopTrackingUserStatus();
    this.#trackUserStatus();
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

  #trackUserStatus() {
    if (this.userStatus.isEnabled) {
      this.user?.statusManager?.trackStatus();
    }
  }

  #stopTrackingUserStatus() {
    if (this.userStatus.isEnabled) {
      this.user?.statusManager?.stopTrackingStatus();
    }
  }

  <template>
    <div
      class="names trigger-user-card"
      {{didUpdate this.refreshUserStatus this.user}}
    >
      <PluginOutlet
        @name="post-meta-data-poster-name"
        @outletArgs={{lazyHash post=@post}}
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
            @outletArgs={{lazyHash position="first" name=this.name post=@post}}
          >
            <UserLink @user={{@post}}>
              {{this.name}}
              {{#if this.showGlyph}}
                {{#if (or @post.moderator @post.group_moderator)}}
                  {{icon "shield-halved" title=(i18n "user.moderator_tooltip")}}
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

          {{#if @post.user_title}}
            <span class={{concatClass "user-title" this.titleClassNames}}>
              {{#if (and @post.primary_group_name @post.title_is_group)}}
                <GroupLink
                  @name={{@post.primary_group_name}}
                  @href={{this.primaryGroupHref}}
                >
                  {{@post.user_title}}
                </GroupLink>
              {{else}}
                {{@post.user_title}}
              {{/if}}
            </span>
          {{/if}}

          {{#if (and this.userStatus.isEnabled this.user.status)}}
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
