import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

const CollapsedInfo = <template>
  <PluginOutlet
    @name="user-profile-above-collapsed-info"
    @outletArgs={{lazyHash model=@model collapsedInfo=@collapsedInfo}}
  />
  {{#unless @collapsedInfo}}
    <div class="secondary" id="collapsed-info-panel">
      <dl>
        {{#if @model.created_at}}
          <div>
            <dt class="created-at">{{i18n "user.created"}}</dt>
            <dd class="created-at">
              {{ageWithTooltip @model.created_at format="medium"}}
            </dd>
          </div>
        {{/if}}
        {{#if @model.last_posted_at}}
          <div>
            <dt class="last-posted-at">{{i18n "user.last_posted"}}</dt>
            <dd class="last-posted-at">
              {{ageWithTooltip @model.last_posted_at format="medium"}}
            </dd>
          </div>
        {{/if}}
        {{#if @model.last_seen_at}}
          <div>
            <dt class="last-seen-at">{{i18n "user.last_seen"}}</dt>
            <dd class="last-seen-at">
              {{ageWithTooltip @model.last_seen_at format="medium"}}
            </dd>
          </div>
        {{/if}}
        {{#if @model.profile_view_count}}
          <div><dt class="profile-view-count">{{i18n "views"}}</dt><dd
              class="profile-view-count"
            >{{@model.profile_view_count}}</dd></div>
        {{/if}}
        {{#if @model.invited_by}}
          <div><dt class="invited-by">{{i18n "user.invited_by"}}</dt><dd
              class="invited-by"
            ><LinkTo
                @route="user"
                @model={{@model.invited_by}}
              >{{@model.invited_by.username}}</LinkTo></dd></div>
        {{/if}}
        {{#if @hasTrustLevel}}
          <div><dt class="trust-level">{{i18n "user.trust_level"}}</dt><dd
              class="trust-level"
            >{{@model.trustLevel.name}}</dd></div>
        {{/if}}
        {{#if @canCheckEmails}}
          <div><dt class="email">{{i18n "user.email.title"}}</dt>
            <dd class="email" title={{@model.email}}>
              {{#if @model.email}}
                {{@model.email}}
              {{else}}
                <DButton
                  @action={{fn (routeAction "checkEmail") @model}}
                  @icon="envelope"
                  @label="admin.users.check_email.text"
                  class="btn-primary"
                />
              {{/if}}
            </dd>
          </div>
        {{/if}}
        {{#if @model.displayGroups}}
          <div><dt class="groups">{{i18n
                "groups.title"
                count=@model.displayGroups.length
              }}</dt>
            <dd class="groups">
              {{#each @model.displayGroups as |group|}}
                <span><LinkTo
                    @route="group"
                    @model={{group.name}}
                    class="group-link"
                  >{{group.name}}</LinkTo></span>
              {{/each}}

              <LinkTo @route="groups" @query={{hash username=@model.username}}>
                ...
              </LinkTo>
            </dd>
          </div>
        {{/if}}

        {{#if @canDeleteUser}}
          <div class="pull-right"><DButton
              @action={{@adminDelete}}
              @icon="triangle-exclamation"
              @label="user.admin_delete"
              class="btn-danger btn-delete-user"
            /></div>
        {{/if}}

        <PluginOutlet
          @name="user-profile-secondary"
          @outletArgs={{lazyHash model=@model}}
        />
      </dl>
    </div>
  {{/unless}}
</template>;

export default CollapsedInfo;
