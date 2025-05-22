import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserBadge from "discourse/components/user-badge";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="admin-controls">
      <nav>
        <ul class="nav nav-pills">
          <li><LinkTo @route="adminUser" @model={{@controller.user}}>{{icon
                "caret-left"
              }}
              &nbsp;{{@controller.user.username}}</LinkTo></li>
        </ul>
      </nav>
    </div>

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>
      <div class="admin-container user-badges">
        <h2>{{i18n "admin.badges.grant_badge"}}</h2>
        <br />
        {{#if @controller.noAvailableBadges}}
          <p>{{i18n "admin.badges.no_badges"}}</p>
        {{else}}
          <PluginOutlet
            @name="badge-granter-form"
            @outletArgs={{lazyHash
              availableBadges=@controller.availableBadges
              userBadges=@controller.userBadges
              user=@controller.user
            }}
          >
            <form class="form-horizontal">
              <div class="control-group">
                <label>{{i18n "admin.badges.badge"}}</label>
                <ComboBox
                  @value={{@controller.selectedBadgeId}}
                  @content={{@controller.availableBadges}}
                  @onChange={{fn (mut @controller.selectedBadgeId)}}
                  @options={{hash filterable=true}}
                />
              </div>
              <div class="control-group">
                <label>{{i18n "admin.badges.reason"}}</label>
                <Input @type="text" @value={{@controller.badgeReason}} /><br
                /><small>{{i18n "admin.badges.reason_help"}}</small>
              </div>
              <DButton
                @action={{@controller.performGrantBadge}}
                @label="admin.badges.grant"
                type="submit"
                class="btn-primary"
              />
            </form>
          </PluginOutlet>
        {{/if}}

        <PluginOutlet
          @name="badge-granter-table"
          @outletArgs={{lazyHash
            groupedBadges=@controller.groupedBadges
            revokeBadge=@controller.revokeBadge
            expandGroup=@controller.expandGroup
          }}
        >
          <table id="user-badges">
            <tbody>
              <tr>
                <th>{{i18n "admin.badges.badge"}}</th>
                <th>{{i18n "admin.badges.granted_by"}}</th>
                <th class="reason">{{i18n "admin.badges.reason"}}</th>
                <th>{{i18n "admin.badges.granted_at"}}</th>
                <th></th>
              </tr>
              {{#each @controller.groupedBadges as |userBadge|}}
                <tr>
                  <td><UserBadge
                      @badge={{userBadge.badge}}
                      @count={{userBadge.count}}
                    /></td>
                  <td>
                    <LinkTo @route="adminUser" @model={{userBadge.granted_by}}>
                      {{avatar userBadge.granted_by imageSize="tiny"}}
                      {{userBadge.granted_by.username}}
                    </LinkTo>
                  </td>
                  <td class="reason">
                    {{#if userBadge.postUrl}}
                      <a
                        href={{userBadge.postUrl}}
                      >{{userBadge.topic_title}}</a>
                    {{/if}}
                  </td>
                  <td>{{ageWithTooltip userBadge.granted_at}}</td>
                  <td>
                    {{#if userBadge.grouped}}
                      <DButton
                        @action={{fn @controller.expandGroup userBadge}}
                        @label="admin.badges.expand"
                      />
                    {{else}}
                      <DButton
                        @action={{fn @controller.revokeBadge userBadge}}
                        @label="admin.badges.revoke"
                        class="btn-danger"
                      />
                    {{/if}}
                  </td>
                </tr>
              {{else}}
                <tr>
                  <td colspan="5">
                    <p>{{i18n
                        "admin.badges.no_user_badges"
                        name=@controller.user.username
                      }}</p>
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </PluginOutlet>
      </div>
    </ConditionalLoadingSpinner>
  </template>
);
