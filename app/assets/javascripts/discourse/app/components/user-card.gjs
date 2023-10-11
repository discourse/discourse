import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import EmberObject, { action, set } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import { dasherize } from "@ember/string";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import HtmlWithLinks from "discourse/components/html-with-links";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserAvatarFlair from "discourse/components/user-avatar-flair";
import UserBadge from "discourse/components/user-badge";
import UserCardAnimation from "discourse/components/user-card-animation";
import UserStatusMessage from "discourse/components/user-status-message";
import boundAvatar from "discourse/helpers/bound-avatar";
import concatClass from "discourse/helpers/concat-class";
import emoji from "discourse/helpers/emoji";
import formatDate from "discourse/helpers/format-date";
import formatDuration from "discourse/helpers/format-duration";
import replaceEmoji from "discourse/helpers/replace-emoji";
import userStatus from "discourse/helpers/user-status";
import { durationTiny } from "discourse/lib/formatter";
import { prioritizeNameInUx } from "discourse/lib/settings";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { formatUsername, modKeysPressed } from "discourse/lib/utilities";
import User from "discourse/models/user";
import icon from "discourse-common/helpers/d-icon";
import { getURLWithCDN } from "discourse-common/lib/get-url";
import I18n from "I18n";
import eq from "truth-helpers/helpers/eq";
import or from "truth-helpers/helpers/or";

export default class UserCard extends Component {
  @service site;
  @service siteSettings;

  @tracked hasUserFilters = false;
  @tracked themeSettingValid = false;
  @tracked showFeaturedTopic = false;
  @tracked showCheckEmail = false;

  @tracked loading = true;
  @tracked user;

  allowBackgrounds = this.siteSettings.allow_profile_backgrounds;
  showUserLocalTime = this.siteSettings.display_local_time_in_user_card;
  showBadges = this.siteSettings.enable_badges;
  moreBadgesLabel = I18n.t("more_badges", { count: this.moreBadgesCount });
  stagedUserLabel = I18n.t("user.staged");
  featuredTopicLabel = I18n.t("user.featured_topic");
  userProfileHiddenLabel = I18n.t("user.profile_hidden");
  inactiveUserLabel = I18n.t("user.inactive_user");
  userSuspendedPermanentlyLabel = I18n.t("user.suspended_permanently");
  userSuspendedTillDateLabel = I18n.t("user.suspended_notice");
  userSuspendedReasonLabel = I18n.t("user.suspended_reason");
  timeReadLabel = I18n.t("time_read");
  timeReadRecentlyLabel = I18n.t("time_read_recently", {
    time_read: this.recentTimeRead,
  });
  lastPostLabel = I18n.t("last_post");

  get showMoreBadges() {
    return this.moreBadgesCount > 0;
  }

  get userTimezone() {
    if (!this.showUserLocalTime) {
      return;
    }
    return this.user.get("user_option.timezone");
  }

  get formattedUserLocalTime() {
    return moment.tz(this.userTimezone).format(I18n.t("dates.time"));
  }

  get isSuspendedOrHasBio() {
    return this.user.suspend_reason || this.user.bio_excerpt;
  }

  get showName() {
    return this.user.name !== this.user.username;
  }

  get linkWebsite() {
    return this.user.isBasic;
  }

  get contentHidden() {
    return this.user?.profile_hidden || this.user.inactive;
  }

  get backgroundImage() {
    if (!this.allowBackgrounds) {
      return;
    }

    if (isEmpty(this.user?.card_background_upload_url)) {
      return;
    }

    return `url(${getURLWithCDN(this.user.card_background_upload_url)})`;
  }

  get nameFirst() {
    return prioritizeNameInUx(this.user.name);
  }

  get showDelete() {
    return this.showName && this.user.canBeDeleted;
  }

  get removeNoFollow() {
    return this.user.trust_level > 2 && !this.siteSettings.tl3_links_no_follow;
  }

  get moreBadgesCount() {
    return this.user?.badge_count - this.user?.featured_user_badges?.length;
  }

  get showRecentTimeRead() {
    const recentTimeRead = this.user.recent_time_read;
    return this.user.time_read !== recentTimeRead && recentTimeRead !== 0;
  }

  get recentTimeRead() {
    return durationTiny(this.user?.recent_time_read);
  }

  get publicUserFields() {
    const siteUserFields = this.site.get("user_fields");
    if (!isEmpty(siteUserFields)) {
      const userFields = this.user.get("user_fields");
      return siteUserFields
        .filterBy("show_on_user_card", true)
        .sortBy("position")
        .map((field) => {
          set(field, "dasherized_name", dasherize(field.name));
          const value = userFields ? userFields[field.id] : null;
          return isEmpty(value) ? null : EmberObject.create({ value, field });
        })
        .compact();
    }
  }

  @action
  handleShowUser(user, event) {
    if (event && modKeysPressed(event).length > 0) {
      return false;
    }
    event?.preventDefault();

    this.args.data.showUser?.(user) ||
      DiscourseURL.routeTo(userPath(user.username_lower));

    this.close();
  }

  @action
  checkEmail(user) {
    user.checkEmail();
  }

  @action
  composePM(user, post) {
    console.log("composePM", user, post);
  }

  @action
  filterPosts() {
    console.log("filterPosts");
  }

  @action
  async close() {
    await this.args.close();
  }

  @action
  cancelFilter() {
    console.log("cancelFilter");
  }

  @action
  deleteUser(user) {
    user.delete();

    this.close();
  }

  @action
  async test() {
    this.loading = true;

    try {
      const args = { forCard: true };

      //       if (user.topic_post_count) {
      //   this.set(
      //     "topicPostCount",
      //     user.topic_post_count[args.include_post_count_for]
      //   );
      // }

      this.user = await User.findByUsername(this.args.data.user.username, args);
      this.user.trackStatus();
    } catch (e) {
      // this._close()
    } finally {
      this.loading = false;
    }
  }

  <template>
    <div
      {{didInsert this.test}}
      style="background-image:{{this.backgroundImage}}"
    >
      <PluginOutlet
        @name="before-user-card-content"
        @outletArgs={{hash user=this.user}}
      />
      {{#if this.loading}}
        <UserCardAnimation />
      {{else}}
        <div class="d-user-card__container">
          <div class="d-user-card__header">
            {{! TODO: Add ability to edit image/color from usercard }}
            {{! <button class="d-user-card__edit-btn">
        <i class="fa-solid fa-pencil"></i>
        <span class="btn-label">Edit</span>
        </button> }}
            {{#unless this.contentHidden}}
              {{#if (or this.showUserLocalTime this.user.location)}}
                <div class="d-user-card__relative-time">
                  {{#if this.showUserLocalTime}}
                    <div class="d-user-card__time">
                      {{icon "far-clock"}}
                      <span class="label">{{this.formattedUserLocalTime}}</span>
                    </div>
                  {{/if}}
                  {{#if this.user.location}}
                    <div class="d-user-card__location">
                      {{icon "map-marker-alt"}}
                      {{#if this.themeSettingValid}}
                        <a
                          href={{this.userLocationLink}}
                          class="label d-user-card__location-link"
                        >{{this.user.location}}</a>
                      {{else}}
                        <span class="label">{{this.user.location}}</span>
                      {{/if}}
                    </div>
                  {{/if}}
                </div>
              {{/if}}
            {{/unless}}
            <div class="d-user-card__badges">
              {{#if this.showBadges}}
                {{#if this.user.featured_user_badges}}
                  {{#each this.user.featured_user_badges as |ub|}}
                    <UserBadge @badge={{ub.badge}} this.user={{this.user}} />
                  {{/each}}
                  {{#if this.showMoreBadges}}
                    <span class="d-user-card__badges-more">
                      <LinkTo @route="user.badges" @model={{this.user}}>
                        {{this.moreBadgesLabel}}
                      </LinkTo>
                    </span>
                  {{/if}}
                {{/if}}
              {{/if}}
            </div>
          </div>
          <div class="d-user-card__main-content">
            <div class="d-user-card__main-content-top">
              <div class="d-user-card__id">
                {{#if this.contentHidden}}
                  <span class="d-user-card__avatar">
                    {{boundAvatar this.user "huge"}}
                  </span>
                {{else}}
                  <a
                    href={{this.user.path}}
                    class="d-user-card__avatar"
                    {{on "click" (fn this.handleShowUser)}}
                  >
                    {{boundAvatar this.user "huge"}}
                  </a>
                {{/if}}
                <UserAvatarFlair this.user={{this.user}} />
                <div>
                  <PluginOutlet
                    @name="user-card-avatar-flair"
                    @connectorTagName="div"
                    @outletArgs={{hash user=this.user}}
                  />
                </div>
                <div class="d-user-card__id-titles">
                  <div class="d-user-card__titles-top">
                    <h1
                      class={{concatClass
                        "d-user-card__name"
                        this.user.staff
                        (eq this.user.trust_level 0)
                        (if this.nameFirst "full-name" "username")
                      }}
                      title="@{{this.user.username}}"
                    >
                      {{#if this.contentHidden}}
                        {{if
                          this.nameFirst
                          this.user.name
                          (formatUsername this.user.username)
                        }}
                      {{else}}
                        <a
                          href={{this.user.path}}
                          title={{if
                            this.nameFirst
                            this.user.name
                            (formatUsername this.user.username)
                          }}
                          {{on "click" (fn this.handleShowUser this.user)}}
                          class="d-user-card__user-link"
                        >
                          {{if
                            this.nameFirst
                            this.user.name
                            (formatUsername this.user.username)
                          }}
                        </a>
                      {{/if}}
                      {{!-- {{userStatus this.user currentUser=this.currentUser}} --}}
                    </h1>
                    {{#if this.user.staged}}
                      <span class="staged">{{this.stagedUserLabel}}</span>
                    {{/if}}
                    <div>
                      <PluginOutlet
                        @name="user-card-post-names"
                        @connectorTagName="div"
                        @outletArgs={{hash user=this.user}}
                      />
                    </div>
                  </div>
                  <div class="d-user-card__titles-bottom">
                    {{#if this.nameFirst}}
                      <span class="d-user-card__user-name" title="Fullname">
                        @{{this.user.username}}
                      </span>
                    {{else}}
                      {{#if this.user.name}}
                        <span class="d-user-card__user-name" title="Fullname">
                          {{this.user.name}}
                        </span>
                      {{/if}}
                    {{/if}}
                    {{#if this.user.title}}
                      <span class="d-user-card__user-title">
                        {{if this.user.name " - "}}{{this.user.title}}
                      </span>
                    {{/if}}
                    {{#if this.user.status}}
                      <UserStatusMessage @status={{this.user.status}} />
                    {{/if}}
                  </div>
                </div>
              </div>
              <div class="d-user-card__user-content">
                {{#if this.showFeaturedTopic}}
                  <div class="d-user-card__featured-topic">
                    <span class="d-user-card__featured-topic-title">
                      {{emoji "pushpin"}}
                    </span>
                    <LinkTo
                      @route="topic"
                      @models={{array
                        this.user.featured_topic.slug
                        this.user.featured_topic.id
                      }}
                      title={{this.featutedTopicLabel}}
                      class="d-user-card__link"
                    >
                      {{replaceEmoji
                        (htmlSafe this.user.featured_topic.fancy_title)
                      }}
                    </LinkTo>
                  </div>
                {{/if}}
                {{#if this.user.profile_hidden}}
                  <span>{{this.userProfileHiddenLabel}}</span>
                {{else if this.user.inactive}}
                  <span>{{this.inactiveUserLabel}}</span>
                {{/if}}

                {{#if this.isSuspendedOrHasBio}}
                  <div class="d-user-card__bio">
                    {{#if this.user.suspend_reason}}
                      <div class="d-user-card__suspension">
                        <div class="d-user-card__suspension-date">
                          {{icon "ban"}}
                          {{#if this.user.suspendedForever}}
                            {{this.suspendedPermanentlyLabel}}
                          {{else}}
                            {{this.suspendedTillDateLabel}}
                          {{/if}}
                        </div>
                        <div class="d-user-card__suspension-reason">
                          <span class="d-user-card__suspension-reason-title">
                            {{this.suspendedReasonLabel}}
                          </span>
                          <span
                            class="d-user-card__suspension-reason-description"
                          >
                            {{this.user.suspend_reason}}
                          </span>
                        </div>
                      </div>
                    {{else}}
                      {{#if this.user.bio_excerpt}}
                        <div class="d-user-card__bio-excerpt">
                          <HtmlWithLinks>
                            <p>
                              {{replaceEmoji (htmlSafe this.user.bio_excerpt)}}
                            </p>
                          </HtmlWithLinks>
                        </div>
                      {{/if}}
                    {{/if}}
                  </div>
                {{/if}}
                {{#unless this.contentHidden}}
                  <div class="d-user-card__custom-fields">
                    <div class="d-user-card__custom-field-group">
                      {{#if this.user.time_read}}
                        <div class="d-user-card__field read">
                          <span
                            class="d-user-card__custom-field-title"
                          >{{this.timeReadlabel}}</span>
                          <span
                            class="d-user-card__custom-field-data"
                          >{{formatDuration this.user.time_read}}
                            {{#if this.showRecentTimeRead}}
                              {{this.timeReadRecentlyLabel}}
                            {{/if}}
                          </span>
                        </div>
                      {{/if}}
                      {{#if this.user.last_posted_at}}
                        <div class="d-user-card__field posted">
                          <span
                            class="d-user-card__custom-field-title"
                          >{{this.lastPostLabel}}</span>
                          <span
                            class="d-user-card__custom-field-data"
                          >{{formatDate
                              this.user.last_posted_at
                              leaveAgo="true"
                            }}</span>
                        </div>
                      {{/if}}
                      {{#if this.showCheckEmail}}
                        <div class="d-user-card__field email">
                          <span class="d-user-card__custom-field-data">
                            {{icon "envelope" title="user.email.title"}}
                            {{#if this.user.email}}
                              {{this.user.email}}
                            {{else}}
                              <DButton
                                @action={{this.checkEmail}}
                                @actionParam={{this.user}}
                                @icon="envelope"
                                @label="admin.users.check_email.text"
                                @class="btn-primary"
                              />
                            {{/if}}
                          </span>
                        </div>
                      {{/if}}
                      <PluginOutlet
                        @name="user-card-metadata"
                        @connectorTagName="div"
                        @outletArgs={{hash user=this.user}}
                      />
                      {{#each this.publicUserFields as |uf|}}
                        {{#if uf.value}}
                          <div
                            class="d-user-card__field
                              {{uf.field.dasherized_name}}"
                          >
                            <span
                              class="d-user-card__custom-field-title"
                            >{{uf.field.name}}</span>
                            <span class="d-user-card__custom-field-data">
                              {{#each uf.value as |v|}}
                                {{! some values are arrays }}
                                {{v}}
                              {{else}}
                                {{uf.value}}
                              {{/each}}
                            </span>
                          </div>
                        {{/if}}
                      {{/each}}
                    </div>
                  </div>
                {{/unless}}
                <PluginOutlet
                  @name="user-card-after-metadata"
                  @connectorTagName="div"
                  @outletArgs={{hash user=this.user}}
                />
                <div class="d-user-card__meta-data">
                  {{#if this.user.website_name}}
                    <div class="d-user-card__website">
                      {{icon "globe"}}
                      <a
                        href={{this.user.website}}
                        rel="noopener {{unless
                          this.removeNoFollow
                          'nofollow ugc'
                        }}"
                        target="_blank"
                        class="d-user-card__link"
                      >{{this.user.website_name}}</a>
                    </div>
                  {{/if}}
                  {{#if this.user.created_at}}
                    <div class="d-user-card__cakeday">
                      <img
                        height="20"
                        width="20"
                        src="https://emoji.discourse-cdn.com/twitter/cake.png?v=12"
                        alt=""
                      />
                      <span class="label">{{formatDate
                          this.user.created_at
                          leaveAgo="true"
                        }}</span>
                    </div>
                  {{/if}}
                  <span>
                    <PluginOutlet
                      @name="user-card-location-and-website"
                      @connectorTagName="div"
                      @outletArgs={{hash user=this.user}}
                    />
                  </span>
                </div>
              </div>
            </div>
            {{#if
              (or
                this.user.can_send_private_message_to_user
                this.showFilter
                this.hasUserFilters
                this.showDelete
              )
            }}
              <div class="d-user-card__main-content-bottom">
                <ul class="d-user-card__controls">
                  {{#if this.user.can_send_private_message_to_user}}
                    <li class="d-user-card__action">
                      <DButton
                        @class="d-user-card__button btn-primary"
                        @action={{fn this.composePM this.user @post}}
                        @icon="envelope"
                        @label="user.private_message"
                      />
                    </li>
                  {{/if}}
                  <PluginOutlet
                    @name="user-card-below-message-button"
                    @connectorTagName="li"
                    @outletArgs={{hash user=this.user close=this.close}}
                  />
                  {{#if this.showFilter}}
                    <li class="d-user-card__action">
                      <DButton
                        @class="d-user-card__button btn-default"
                        @action={{fn this.filterPosts this.user}}
                        @icon="filter"
                        @translatedLabel={{this.filterPostsLabel}}
                      />
                    </li>
                  {{/if}}
                  {{#if this.hasUserFilters}}
                    <li class="d-user-card__action">
                      <DButton
                        @class="d-user-card__button btn-default"
                        @action={{this.cancelFilter}}
                        @icon="times"
                        @label="topic.filters.cancel"
                      />
                    </li>
                  {{/if}}
                  {{#if this.showDelete}}
                    <li class="d-user-card__action">
                      <DButton
                        @class="d-user-card__button btn-danger"
                        @action={{fn this.deleteUser this.user}}
                        @actionParam={{this.user}}
                        @icon="exclamation-triangle"
                        @label="admin.user.delete"
                      />
                    </li>
                  {{/if}}
                  <PluginOutlet
                    @name="user-card-additional-buttons"
                    @outletArgs={{hash user=this.user close=this.close}}
                  />
                </ul>
                <PluginOutlet
                  @name="user-card-additional-controls"
                  @connectorTagName="div"
                  @outletArgs={{hash user=this.user close=this.close}}
                />
              </div>
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
