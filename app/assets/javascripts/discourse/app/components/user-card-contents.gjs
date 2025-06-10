import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import EmberObject, { action, computed, set } from "@ember/object";
import { alias, and, gt, gte, not, or } from "@ember/object/computed";
import { LinkTo } from "@ember/routing";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import {
  attributeBindings,
  classNameBindings,
  classNames,
} from "@ember-decorators/component";
import { observes, on as onEvent } from "@ember-decorators/object";
import CardContentsBase from "discourse/components/card-contents-base";
import DButton from "discourse/components/d-button";
import HtmlWithLinks from "discourse/components/html-with-links";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import UserBadge from "discourse/components/user-badge";
import boundAvatar from "discourse/helpers/bound-avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatDuration from "discourse/helpers/format-duration";
import formatUsername from "discourse/helpers/format-username";
import lazyHash from "discourse/helpers/lazy-hash";
import replaceEmoji from "discourse/helpers/replace-emoji";
import userStatus from "discourse/helpers/user-status";
import CanCheckEmailsHelper from "discourse/lib/can-check-emails-helper";
import { setting } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { durationTiny } from "discourse/lib/formatter";
import { getURLWithCDN } from "discourse/lib/get-url";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

@classNames("user-card")
@classNameBindings(
  "visible:show",
  "showBadges",
  "user.card_background_upload_url::no-bg",
  "isFixed:fixed",
  "usernameClass",
  "primaryGroup"
)
@attributeBindings("ariaLabel:aria-label")
export default class UserCardContents extends CardContentsBase {
  elementId = "user-card";
  avatarSelector = "[data-user-card]";
  avatarDataAttrKey = "userCard";
  mentionSelector = "a.mention";
  ariaLabel = i18n("user.card");

  @setting("allow_profile_backgrounds") allowBackgrounds;
  @setting("enable_badges") showBadges;
  @setting("display_local_time_in_user_card") showUserLocalTime;
  @setting("moderators_view_emails") canModeratorsViewEmails;

  @alias("topic.postStream") postStream;

  @gte("topicPostCount", 2) enoughPostsForFiltering;

  @and("viewingTopic", "postStream.hasNoFilters", "enoughPostsForFiltering")
  showFilter;

  @gt("postStream.userFilters.length", 0) hasUserFilters;
  @gt("moreBadgesCount", 0) showMoreBadges;
  @and("viewingAdmin", "showName", "user.canBeDeleted") showDelete;
  @not("user.isBasic") linkWebsite;
  @or("user.suspend_reason", "user.bio_excerpt") isSuspendedOrHasBio;
  @and("user.staged", "canCheckEmails") showCheckEmail;

  user = null;

  // If inside a topic
  topicPostCount = null;

  @and(
    "user.featured_topic",
    "siteSettings.allow_featured_topic_on_user_profiles"
  )
  showFeaturedTopic;

  @computed("user.name", "user.username")
  get showName() {
    return this.user.name !== this.user.username;
  }

  @computed("model.id", "currentUser.id")
  get canCheckEmails() {
    return new CanCheckEmailsHelper(
      this.model,
      this.canModeratorsViewEmails,
      this.currentUser
    ).canCheckEmails;
  }

  @discourseComputed("user")
  hasLocaleOrWebsite(user) {
    return user.location || user.website_name || this.userTimezone;
  }

  @discourseComputed("user.status")
  hasStatus() {
    return this.siteSettings.enable_user_status && this.user.status;
  }

  @discourseComputed("user.status.emoji")
  userStatusEmoji(emoji) {
    return emojiUnescape(escapeExpression(`:${emoji}:`));
  }

  @discourseComputed("user.staff")
  staff(isStaff) {
    return isStaff ? "staff" : "";
  }

  @discourseComputed("user.trust_level")
  newUser(trustLevel) {
    return trustLevel === 0 ? "new-user" : "";
  }

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  }

  @discourseComputed("user")
  userTimezone(user) {
    if (!this.showUserLocalTime) {
      return;
    }
    return user.get("user_option.timezone");
  }

  @discourseComputed("userTimezone")
  formattedUserLocalTime(timezone) {
    return moment.tz(timezone).format(i18n("dates.time"));
  }

  @discourseComputed("username")
  usernameClass(username) {
    return username ? `user-card-${username}` : "";
  }

  @discourseComputed("username", "topicPostCount")
  filterPostsLabel(username, count) {
    return i18n("topic.filter_to", { username, count });
  }

  @discourseComputed("user.user_fields.@each.value")
  publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.get("user.user_fields");
      return siteUserFields
        .filterBy("show_on_user_card", true)
        .sortBy("position")
        .map((field) => {
          set(field, "dasherized_name", dasherize(field.get("name")));
          const value = userFields ? userFields[field.get("id")] : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  }

  @discourseComputed("user.trust_level")
  removeNoFollow(trustLevel) {
    return trustLevel > 2 && !this.siteSettings.tl3_links_no_follow;
  }

  @discourseComputed("user.badge_count", "user.featured_user_badges.length")
  moreBadgesCount(badgeCount, badgeLength) {
    return badgeCount - badgeLength;
  }

  @discourseComputed("user.time_read", "user.recent_time_read")
  showRecentTimeRead(timeRead, recentTimeRead) {
    return timeRead !== recentTimeRead && recentTimeRead !== 0;
  }

  @discourseComputed("user.recent_time_read")
  recentTimeRead(recentTimeReadSeconds) {
    return durationTiny(recentTimeReadSeconds);
  }

  @discourseComputed("showRecentTimeRead", "user.time_read", "recentTimeRead")
  timeReadTooltip(showRecent, timeRead, recentTimeRead) {
    if (showRecent) {
      return i18n("time_read_recently_tooltip", {
        time_read: durationTiny(timeRead),
        recent_time_read: recentTimeRead,
      });
    } else {
      return i18n("time_read_tooltip", {
        time_read: durationTiny(timeRead),
      });
    }
  }

  @observes("user.card_background_upload_url")
  addBackground() {
    if (!this.allowBackgrounds) {
      return;
    }

    if (!this.element) {
      return;
    }

    const url = this.get("user.card_background_upload_url");
    const bg = isEmpty(url) ? "" : `url(${getURLWithCDN(url)})`;
    this.element.style.backgroundImage = bg;
  }

  @discourseComputed("user.primary_group_name")
  primaryGroup(primaryGroup) {
    return `group-${primaryGroup}`;
  }

  @discourseComputed("user.profile_hidden", "user.inactive")
  contentHidden(profileHidden, inactive) {
    return profileHidden || inactive;
  }

  @onEvent("didInsertElement")
  _inserted() {
    this.appEvents.on("dom:clean", this, this.cleanUp);
  }

  @onEvent("didDestroyElement")
  _destroyed() {
    this.appEvents.off("dom:clean", this, this.cleanUp);
  }

  async _showCallback(username) {
    this.setProperties({ visible: true, loading: true });

    const args = {
      forCard: true,
      include_post_count_for: this.get("topic.id"),
    };

    try {
      const user = await User.findByUsername(username, args);

      if (user.topic_post_count) {
        this.set(
          "topicPostCount",
          user.topic_post_count[args.include_post_count_for]
        );
      }
      this.setProperties({ user });
      this.user.statusManager.trackStatus();

      return user;
    } catch {
      this._close();
    } finally {
      this.set("loading", null);
    }
  }

  _close() {
    this.user?.statusManager.stopTrackingStatus();

    this.setProperties({
      user: null,
      topicPostCount: null,
    });

    super._close(...arguments);
  }

  cleanUp() {
    this._close();
  }

  @action
  refreshRoute(value) {
    this.router.transitionTo({ queryParams: { name: value } });
  }

  @action
  handleShowUser(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    // Invokes `showUser` argument. Convert to `this.args.showUser` when
    // refactoring this to a glimmer component.
    this.showUser(this.user);
    this._close();
  }

  @action
  close() {
    this._close();
  }

  @action
  composePM(user, post) {
    this._close();
    this.composePrivateMessage(user, post);
  }

  @action
  cancelFilter() {
    this.postStream.cancelFilter();
    this.postStream.refresh();
    this._close();
  }

  @action
  handleFilterPosts() {
    this.filterPosts(this.user);
    this._close();
  }

  @action
  deleteUser() {
    this.user.delete();
    this._close();
  }

  @action
  checkEmail(user) {
    user.checkEmail();
  }

  <template>
    {{#if this.visible}}
      <PluginOutlet
        @name="before-user-card-content"
        @outletArgs={{lazyHash user=this.user}}
      />
      <div class="card-content">
        {{#if this.loading}}
          <div class="card-row first-row">
            <div class="user-card-avatar">
              <div
                class="card-avatar-placeholder animated-placeholder placeholder-animation"
              ></div>
            </div>
          </div>

          <div class="card-row second-row">
            <div class="animated-placeholder placeholder-animation"></div>
          </div>
          <div class="card-row">
            <div class="animated-placeholder placeholder-animation"></div>
          </div>
          <div class="card-row">
            <div class="animated-placeholder placeholder-animation"></div>
          </div>
          <div class="card-row">
            <div class="animated-placeholder placeholder-animation"></div>
          </div>
        {{else}}
          <div class="card-row first-row">
            <PluginOutlet
              @name="user-card-main-info"
              @outletArgs={{lazyHash
                user=this.user
                post=this.post
                contentHidden=this.contentHidden
                handleShowUser=this.handleShowUser
              }}
            >
              <div class="user-card-avatar" aria-hidden="true">
                {{#if this.contentHidden}}
                  <span class="card-huge-avatar">{{boundAvatar
                      this.user
                      "huge"
                    }}</span>
                {{else}}
                  <a
                    {{on "click" this.handleShowUser}}
                    href={{this.user.path}}
                    class="card-huge-avatar"
                    tabindex="-1"
                  >{{boundAvatar this.user "huge"}}</a>
                {{/if}}

                <UserAvatarFlair @user={{this.user}} />

                <div>
                  <PluginOutlet
                    @name="user-card-avatar-flair"
                    @connectorTagName="div"
                    @outletArgs={{lazyHash user=this.user}}
                  />
                </div>
              </div>
              <div class="names">
                <div
                  class="names__primary
                    {{this.staff}}
                    {{this.newUser}}
                    {{if this.nameFirst 'full-name' 'username'}}"
                >
                  {{#if this.contentHidden}}
                    <span class="name-username-wrapper">
                      {{if
                        this.nameFirst
                        this.user.name
                        (formatUsername this.user.username)
                      }}
                    </span>
                  {{else}}
                    <a
                      {{on "click" this.handleShowUser}}
                      href={{this.user.path}}
                      class="user-profile-link"
                      aria-label={{i18n
                        "user.profile_link"
                        username=this.user.username
                      }}
                    >
                      <span class="name-username-wrapper">
                        {{if
                          this.nameFirst
                          this.user.name
                          (formatUsername this.user.username)
                        }}
                      </span>
                      {{userStatus this.user currentUser=this.currentUser}}
                    </a>
                  {{/if}}
                </div>
                <PluginOutlet
                  @name="user-card-after-username"
                  @connectorTagName="div"
                  @outletArgs={{lazyHash
                    user=this.user
                    showUser=this.handleShowUser
                  }}
                />
                {{#if this.nameFirst}}
                  <div
                    class="names__secondary username"
                  >{{this.user.username}}</div>
                {{else}}
                  {{#if this.user.name}}
                    <div
                      class="names__secondary full-name"
                    >{{this.user.name}}</div>
                  {{/if}}
                {{/if}}
                {{#if this.user.title}}
                  <div class="names__secondary">{{this.user.title}}</div>
                {{/if}}
                {{#if this.user.staged}}
                  <div class="names__secondary staged">{{i18n
                      "user.staged"
                    }}</div>
                {{/if}}
                {{#if this.hasStatus}}
                  <div class="user-status">
                    {{htmlSafe this.userStatusEmoji}}
                    <span class="user-status__description">
                      {{this.user.status.description}}
                    </span>
                    {{formatDate this.user.status.ends_at format="tiny"}}
                  </div>
                {{/if}}
                <div>
                  <PluginOutlet
                    @name="user-card-post-names"
                    @connectorTagName="div"
                    @outletArgs={{lazyHash user=this.user}}
                  />
                </div>
              </div>
            </PluginOutlet>
            <ul class="usercard-controls">
              {{#if this.user.can_send_private_message_to_user}}
                <li class="compose-pm">
                  <DButton
                    @action={{fn this.composePM this.user this.post}}
                    @icon="envelope"
                    @label="user.private_message"
                    class="btn-primary"
                  />
                </li>
              {{/if}}
              <PluginOutlet
                @name="user-card-below-message-button"
                @connectorTagName="li"
                @outletArgs={{lazyHash user=this.user close=this.close}}
              />
              {{#if this.showFilter}}
                <li>
                  <DButton
                    @action={{fn this.handleFilterPosts this.user}}
                    @icon="filter"
                    @translatedLabel={{this.filterPostsLabel}}
                    class="btn-default"
                  />
                </li>
              {{/if}}
              {{#if this.hasUserFilters}}
                <li>
                  <DButton
                    @action={{this.cancelFilter}}
                    @icon="xmark"
                    @label="topic.filters.cancel"
                  />
                </li>
              {{/if}}
              {{#if this.showDelete}}
                <li>
                  <DButton
                    @action={{fn this.deleteUser this.user}}
                    @icon="triangle-exclamation"
                    @label="admin.user.delete"
                    class="btn-danger"
                  />
                </li>
              {{/if}}
              <PluginOutlet
                @name="user-card-additional-buttons"
                @connectorTagName="li"
                @outletArgs={{lazyHash user=this.user close=this.close}}
              />
            </ul>
            <PluginOutlet
              @name="user-card-additional-controls"
              @connectorTagName="div"
              @outletArgs={{lazyHash user=this.user close=this.close}}
            />
          </div>

          {{#if this.user.profile_hidden}}
            <div class="card-row second-row">
              <div class="profile-hidden">
                <span role="alert">{{i18n "user.profile_hidden"}}</span>
              </div>
            </div>
          {{else if this.user.inactive}}
            <div class="card-row second-row">
              <div class="inactive-user">
                <span role="alert">{{i18n "user.inactive_user"}}</span>
              </div>
            </div>
          {{/if}}

          {{#if this.isSuspendedOrHasBio}}
            <div class="card-row second-row">
              {{#if this.user.suspend_reason}}
                <div class="suspended">
                  <div class="suspension-date">
                    {{icon "ban"}}
                    {{#if this.user.suspendedForever}}
                      {{i18n "user.suspended_permanently"}}
                    {{else}}
                      {{i18n
                        "user.suspended_notice"
                        date=this.user.suspendedTillDate
                      }}
                    {{/if}}
                  </div>
                  <div class="suspension-reason">
                    <span class="suspension-reason-title">{{i18n
                        "user.suspended_reason"
                      }}</span>
                    <span
                      class="suspension-reason-description"
                    >{{this.user.suspend_reason}}</span>
                  </div>
                </div>
              {{else}}
                {{#if this.user.bio_excerpt}}
                  <div class="bio">
                    <HtmlWithLinks>
                      {{htmlSafe this.user.bio_excerpt}}
                    </HtmlWithLinks>
                  </div>
                {{/if}}
              {{/if}}
            </div>
          {{/if}}

          {{#if this.showFeaturedTopic}}
            <div class="card-row">
              <div class="featured-topic">
                <span class="desc">{{i18n "user.featured_topic"}}</span>
                <LinkTo
                  @route="topic"
                  @models={{array
                    this.user.featured_topic.slug
                    this.user.featured_topic.id
                  }}
                >{{replaceEmoji
                    (htmlSafe this.user.featured_topic.fancy_title)
                  }}</LinkTo>
              </div>
            </div>
          {{/if}}

          {{#if this.hasLocaleOrWebsite}}
            <div class="card-row">
              <div class="location-and-website">
                {{#if this.user.website_name}}
                  <span class="website-name">
                    {{icon "globe"}}
                    {{#if this.linkWebsite}}
                      {{! template-lint-disable link-rel-noopener }}
                      <a
                        href={{this.user.website}}
                        rel="noopener {{unless
                          this.removeNoFollow
                          'nofollow ugc'
                        }}"
                        target="_blank"
                      >{{this.user.website_name}}</a>
                      {{! template-lint-enable link-rel-noopener }}
                    {{else}}
                      <span
                        title={{this.user.website}}
                      >{{this.user.website_name}}</span>
                    {{/if}}
                  </span>
                {{/if}}
                {{#if this.user.location}}
                  <span class="location">
                    {{icon "location-dot"}}
                    <span>{{this.user.location}}</span>
                  </span>
                {{/if}}
                {{#if this.showUserLocalTime}}
                  <span class="local-time" title={{i18n "local_time"}}>
                    {{icon "far-clock"}}
                    <span>{{this.formattedUserLocalTime}}</span>
                  </span>
                {{/if}}
                <span>
                  <PluginOutlet
                    @name="user-card-location-and-website"
                    @connectorTagName="div"
                    @outletArgs={{lazyHash user=this.user}}
                  />
                </span>
              </div>
            </div>
          {{/if}}

          <div class="card-row metadata-row">
            {{#unless this.contentHidden}}
              <div class="metadata">
                {{#if this.user.last_posted_at}}
                  <div class="metadata__last-posted">
                    <span class="desc">{{i18n "last_post"}}</span>
                    {{formatDate
                      this.user.last_posted_at
                      leaveAgo="true"
                    }}</div>
                {{/if}}
                <div class="metadata__user-created">
                  <span class="desc">{{i18n "joined"}}</span>
                  {{formatDate this.user.created_at leaveAgo="true"}}</div>
                {{#if this.user.time_read}}
                  <div
                    class="metadata__time-read"
                    title={{this.timeReadTooltip}}
                  >
                    <span class="desc">{{i18n "time_read"}}</span>
                    {{formatDuration this.user.time_read}}
                    {{#if this.showRecentTimeRead}}
                      <span>
                        ({{i18n
                          "time_read_recently"
                          time_read=this.recentTimeRead
                        }})
                      </span>
                    {{/if}}
                  </div>
                {{/if}}
                {{#if this.showCheckEmail}}
                  <div class="metadata__email">
                    {{icon "envelope" title="user.email.title"}}
                    {{#if this.user.email}}
                      {{this.user.email}}
                    {{else}}
                      <DButton
                        @action={{fn this.checkEmail this.user}}
                        @icon="envelope"
                        @label="admin.users.check_email.text"
                        class="btn-primary"
                      />
                    {{/if}}
                  </div>
                {{/if}}
                <PluginOutlet
                  @name="user-card-metadata"
                  @connectorTagName="div"
                  @outletArgs={{lazyHash user=this.user}}
                />
              </div>
            {{/unless}}
            <PluginOutlet
              @name="user-card-after-metadata"
              @connectorTagName="div"
              @outletArgs={{lazyHash user=this.user}}
            />
          </div>

          {{#if this.publicUserFields}}
            <div class="card-row">
              <div class="public-user-fields">
                {{#each this.publicUserFields as |uf|}}
                  {{#if uf.value}}
                    <div
                      class="public-user-field public-user-field__{{uf.field.dasherized_name}}"
                    >
                      <span class="user-field-name">{{uf.field.name}}:</span>
                      <span class="user-field-value">
                        {{#each uf.value as |v|}}
                          {{! some values are arrays }}
                          <span class="user-field-value-list-item">
                            {{#if uf.field.searchable}}
                              <LinkTo
                                @route="users"
                                @query={{hash name=v}}
                                {{on "click" (fn this.refreshRoute v)}}
                              >{{v}}</LinkTo>
                            {{else}}
                              {{v}}
                            {{/if}}
                          </span>
                        {{else}}
                          {{uf.value}}
                        {{/each}}
                      </span>
                    </div>
                  {{/if}}
                {{/each}}
              </div>
            </div>
          {{/if}}

          <PluginOutlet
            @name="user-card-before-badges"
            @connectorTagName="div"
            @outletArgs={{lazyHash user=this.user}}
          />

          {{#if this.showBadges}}
            <div class="card-row">
              <PluginOutlet
                @name="user-card-badges"
                @outletArgs={{lazyHash user=this.user post=this.post}}
              >
                {{#if this.user.featured_user_badges}}
                  <div class="badge-section">
                    {{#each this.user.featured_user_badges as |ub|}}
                      <UserBadge @badge={{ub.badge}} @user={{this.user}} />
                    {{/each}}
                    {{#if this.showMoreBadges}}
                      <span class="more-user-badges">
                        <LinkTo @route="user.badges" @model={{this.user}}>
                          {{i18n
                            "badges.more_badges"
                            count=this.moreBadgesCount
                          }}
                        </LinkTo>
                      </span>
                    {{/if}}
                  </div>
                {{/if}}
              </PluginOutlet>
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{/if}}
  </template>
}
