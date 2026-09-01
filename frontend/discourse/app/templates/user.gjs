import { array, concat, fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserNav from "discourse/components/user-nav";
import UserProfileAvatar from "discourse/components/user-profile-avatar";
import formatUsername from "discourse/helpers/format-username";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import userStatus from "discourse/helpers/user-status";
import UserNotificationsDropdown from "discourse/select-kit/components/user-notifications-dropdown";
import { and, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHtmlWithLinks from "discourse/ui-kit/d-html-with-links";
import DUserStatusMessage from "discourse/ui-kit/d-user-status-message";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";
import CollapsedInfo from "./user/collapsed-info";

export default <template>
  <PluginOutlet
    @connectorTagName="div"
    @name="above-user-profile"
    @outletArgs={{lazyHash model=@controller.model}}
  />
  <div
    class="container
      {{if @controller.viewingSelf 'viewing-self'}}
      {{if @controller.model.profile_hidden 'profile-hidden'}}
      {{@controller.primaryGroup}}"
  >
    <section class="user-main">
      <a
        class="skip-link__user-nav"
        href="#user-content"
        id="user-nav-skip-link"
      >
        {{i18n "skip_user_nav"}}
      </a>
      <section
        class="{{if @controller.collapsedInfo 'collapsed-info'}}
          about
          {{if
            @controller.hasProfileBackgroundUrl
            'has-background'
            'no-background'
          }}"
      >
        {{#unless @controller.collapsedInfo}}
          {{#if @controller.showStaffCounters}}
            <div class="staff-counters">
              {{#if @controller.model.number_of_flags_given}}
                <div>
                  <LinkTo
                    @query={{hash
                      flagged_by=@controller.model.username
                      status="approved"
                    }}
                    @route="review"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.flags_given"
                        className="helpful-flags"
                        count=@controller.model.number_of_flags_given
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}
              {{#if @controller.model.number_of_flags}}
                <div>
                  <LinkTo
                    @query={{hash
                      username=@controller.model.username
                      status="all"
                    }}
                    @route="review"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.flags"
                        className="flags"
                        count=@controller.model.number_of_flags
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}
              {{#if @controller.model.number_of_rejected_posts}}
                <div>
                  <LinkTo
                    @query={{hash
                      username=@controller.model.username
                      status="rejected"
                      type="ReviewableQueuedPost"
                    }}
                    @route="review"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.rejected_posts"
                        className="flagged-posts"
                        count=@controller.model.number_of_rejected_posts
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}

              {{#if @controller.model.number_of_deleted_posts}}
                <div>
                  <LinkTo
                    @model={{@controller.model}}
                    @route="user.deletedPosts"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.deleted_posts"
                        className="deleted-posts"
                        count=@controller.model.number_of_deleted_posts
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}
              {{#if @controller.model.number_of_silencings}}
                <div>
                  <LinkTo
                    @query={{@controller.silencingsRouteQuery}}
                    @route="adminLogs.staffActionLogs"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.silencings"
                        className="silencings"
                        count=@controller.model.number_of_silencings
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}
              {{#if @controller.model.number_of_suspensions}}
                <div>
                  <LinkTo
                    @query={{@controller.suspensionsRouteQuery}}
                    @route="adminLogs.staffActionLogs"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.suspensions"
                        className="suspensions"
                        count=@controller.model.number_of_suspensions
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}
              {{#if @controller.model.warnings_received_count}}
                <div>
                  <LinkTo
                    @model={{@controller.model}}
                    @route="userPrivateMessages.user.warnings"
                  >
                    {{trustHTML
                      (i18n
                        "user.staff_counters.warnings_received"
                        className="warnings-received"
                        count=@controller.model.warnings_received_count
                      )
                    }}
                  </LinkTo>
                </div>
              {{/if}}
            </div>
          {{/if}}
          <div
            class="user-profile-image"
            style={{@controller.model.profileBackgroundUrl}}
          ></div>
        {{/unless}}
        <div class="details">
          <div class="primary">
            <PluginOutlet
              @name="before-user-profile-avatar"
              @outletArgs={{lazyHash model=@controller.model}}
            />
            <UserProfileAvatar @user={{@controller.model}} />
            <div class="primary-textual">
              <div class="user-profile-names">
                <div
                  class="{{if @controller.nameFirst 'full-name' 'username'}}
                    user-profile-names__primary"
                >
                  {{if
                    @controller.nameFirst
                    @controller.model.name
                    (formatUsername @controller.model.username)
                  }}
                  {{userStatus
                    @controller.model
                    currentUser=@controller.currentUser
                  }}
                  {{#if @controller.model.status}}
                    <DUserStatusMessage @status={{@controller.model.status}} />
                  {{/if}}
                </div>
                <div
                  class="{{if @controller.nameFirst 'username' 'full-name'}}
                    user-profile-names__secondary"
                >{{#if
                    @controller.nameFirst
                  }}{{@controller.model.username}}{{else}}{{@controller.model.name}}{{/if}}</div>
                {{#if @controller.model.staged}}
                  <div class="staged user-profile-names__secondary">{{i18n
                      "user.staged"
                    }}</div>
                {{/if}}
                {{#if @controller.model.title}}
                  <div
                    class="user-profile-names__title"
                  >{{@controller.model.title}}</div>
                {{/if}}
                <span>
                  <PluginOutlet
                    @connectorTagName="div"
                    @name="user-post-names"
                    @outletArgs={{lazyHash model=@controller.model}}
                  />
                </span>
              </div>

              {{#if @controller.showFeaturedTopic}}
                <div class="featured-topic user-profile__featured-topic">
                  <span title={{i18n "user.featured_topic"}}>
                    {{dIcon "book"~}}
                  </span><LinkTo
                    @models={{array
                      @controller.model.featured_topic.slug
                      @controller.model.featured_topic.id
                    }}
                    @route="topic"
                  >{{dReplaceEmoji
                      (trustHTML @controller.model.featured_topic.fancy_title)
                    }}</LinkTo>
                </div>
              {{/if}}

              <div
                class="location-and-website user-profile__location-and-website"
              >
                {{#if @controller.model.location}}<div
                    class="user-profile-location"
                  >{{dIcon "location-dot"~}}
                    {{@controller.model.location}}</div>{{/if}}
                {{#if @controller.model.website_name}}
                  <div class="user-profile-website">
                    {{! eslint-disable ember/template-link-rel-noopener }}
                    {{dIcon "globe"~}}
                    {{#if @controller.linkWebsite~}}
                      <a
                        href={{@controller.model.website}}
                        rel="noopener {{unless
                          @controller.removeNoFollow
                          'nofollow ugc'
                        }}"
                        target="_blank"
                      >{{@controller.model.website_name}}</a>
                    {{else}}
                      <span
                        title={{@controller.model.website}}
                      >{{@controller.model.website_name}}</span>
                    {{/if}}
                    {{! eslint-enable ember/template-link-rel-noopener }}
                  </div>
                {{/if}}
                <span>
                  <PluginOutlet
                    @connectorTagName="div"
                    @name="user-location-and-website"
                    @outletArgs={{lazyHash model=@controller.model}}
                  />
                </span>
              </div>

              <PluginOutlet
                @connectorTagName="div"
                @name="before-user-profile-bio"
                @outletArgs={{lazyHash
                  model=@controller.model
                  publicUserFields=@controller.publicUserFields
                  collapsedInfo=@controller.collapsedInfo
                  hasTrustLevel=@controller.hasTrustLevel
                  canCheckEmails=@controller.canCheckEmails
                  canDeleteUser=@controller.canDeleteUser
                  adminDelete=@controller.adminDelete
                }}
              />

              <div class="bio">
                {{#if @controller.model.suspended}}
                  <div class="suspended">
                    <div class="suspension-date">
                      {{dIcon "ban"}}
                      <b>
                        {{#if @controller.model.suspendedForever}}
                          {{i18n "user.suspended_permanently"}}
                        {{else}}
                          {{i18n
                            "user.suspended_notice"
                            date=@controller.model.suspendedTillDate
                          }}
                        {{/if}}
                      </b>
                    </div>
                    {{#if @controller.model.suspend_reason}}
                      <div class="suspension-reason">
                        <b>{{i18n "user.suspended_reason"}}</b>
                        {{trustHTML @controller.model.suspend_reason}}
                      </div>
                    {{/if}}
                  </div>
                {{/if}}
                {{#if @controller.model.silenced}}
                  <div class="silenced">
                    <div class="silence-date">
                      {{dIcon "microphone-slash"}}
                      <b>
                        {{#if @controller.model.silencedForever}}
                          {{i18n "user.silenced_permanently"}}
                        {{else}}
                          {{i18n
                            "user.silenced_notice"
                            date=@controller.model.silencedTillDate
                          }}
                        {{/if}}
                      </b>
                    </div>
                    {{#if @controller.model.silence_reason}}
                      <div class="silence-reason">
                        <b>{{i18n "user.silenced_reason"}}</b>
                        {{trustHTML @controller.model.silence_reason}}
                      </div>
                    {{/if}}
                  </div>
                {{/if}}
                {{#if @controller.isNotRestrictedOrIsStaff}}
                  <DHtmlWithLinks>
                    {{trustHTML @controller.model.bio_cooked}}
                  </DHtmlWithLinks>
                {{/if}}
              </div>

              {{#if @controller.publicUserFields}}
                <div class="public-user-fields">
                  {{#each @controller.publicUserFields as |uf|}}

                    {{#if uf.value}}
                      <div
                        class="public-user-field {{uf.field.dasherized_name}}"
                      >
                        <span class="user-field-name">{{uf.field.name}}</span>:
                        <span class="user-field-value">
                          {{#each uf.value as |v|}}
                            {{! some values are arrays }}
                            <span class="user-field-value-list-item">
                              {{#if uf.field.searchable}}
                                <LinkTo
                                  @query={{hash name=v}}
                                  @route="users"
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

                  <span>
                    <PluginOutlet
                      @connectorTagName="div"
                      @name="user-profile-public-fields"
                      @outletArgs={{lazyHash
                        publicUserFields=@controller.publicUserFields
                        model=@controller.model
                      }}
                    />
                  </span>
                </div>
              {{/if}}

              <span>
                <PluginOutlet
                  @connectorTagName="div"
                  @name="user-profile-primary"
                  @outletArgs={{lazyHash model=@controller.model}}
                />
              </span>
            </div>

            <section class="controls">
              <ul>
                {{#if
                  (and
                    @controller.model.can_send_private_message_to_user
                    (not @controller.viewingSelf)
                  )
                }}
                  <li>
                    <DButton
                      class="btn-primary compose-pm"
                      @action={{fn
                        (routeAction "composePrivateMessage")
                        @controller.model
                      }}
                      @icon="envelope"
                      @label="user.private_message"
                    />
                  </li>
                {{/if}}

                {{#if @controller.canMuteOrIgnoreUser}}
                  <li>
                    <UserNotificationsDropdown
                      @updateNotificationLevel={{@controller.updateNotificationLevel}}
                      @user={{@controller.model}}
                      @value={{@controller.userNotificationLevel}}
                    />
                  </li>
                {{/if}}

                {{#if @controller.displayTopLevelAdminButton}}
                  <li><a
                      class="btn btn-default user-admin"
                      href={{@controller.model.adminPath}}
                    >{{dIcon "wrench"}}<span class="d-button-label">{{i18n
                          "admin.user.show_admin_profile"
                        }}</span></a></li>
                {{/if}}

                <PluginOutlet
                  @connectorTagName="li"
                  @name="user-profile-controls"
                  @outletArgs={{lazyHash model=@controller.model}}
                />

                {{#if @controller.canExpandProfile}}
                  <li>
                    <DButton
                      aria-controls="collapsed-info-panel"
                      aria-expanded={{if
                        @controller.collapsedInfoState.isExpanded
                        "true"
                        "false"
                      }}
                      class="btn-default user-profile-toggle-btn"
                      @action={{@controller.collapsedInfoState.action}}
                      @ariaLabel={{@controller.collapsedInfoState.ariaLabel}}
                      @icon={{@controller.collapsedInfoState.icon}}
                      @label={{concat
                        "user."
                        @controller.collapsedInfoState.label
                      }}
                    />
                  </li>
                {{/if}}
              </ul>
            </section>
          </div>
          <CollapsedInfo
            @adminDelete={{@controller.adminDelete}}
            @adminDeleteOptions={{@controller.adminDeleteOptions}}
            @canCheckEmails={{@controller.canCheckEmails}}
            @canDeleteUser={{@controller.canDeleteUser}}
            @collapsedInfo={{@controller.collapsedInfo}}
            @hasTrustLevel={{@controller.hasTrustLevel}}
            @model={{@controller.model}}
          />
        </div>
      </section>

      <div class="new-user-wrapper">
        <UserNav
          @canInviteToForum={{@controller.canInviteToForum}}
          @currentParentRoute={{@controller.currentParentRoute}}
          @isMobileView={{@controller.site.mobileView}}
          @isStaff={{@controller.currentUser.staff}}
          @showActivityTab={{@controller.showActivityTab}}
          @showBadges={{@controller.showBadges}}
          @showBookmarks={{@controller.showBookmarks}}
          @showDrafts={{@controller.showDrafts}}
          @showNotificationsTab={{@controller.showNotificationsTab}}
          @showPrivateMessages={{@controller.showPrivateMessages}}
          @showRead={{@controller.showRead}}
          @user={{@controller.model}}
        />

        <div class="new-user-content-wrapper">
          {{outlet}}
        </div>
      </div>
    </section>
  </div>
</template>
