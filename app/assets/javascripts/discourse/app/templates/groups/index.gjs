import RouteTemplate from 'ember-route-template'
import or from "truth-helpers/helpers/or";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import bodyClass from "discourse/helpers/body-class";
import PluginOutlet from "discourse/components/plugin-outlet";
import DButton from "discourse/components/d-button";
import { Input } from "@ember/component";
import i18n from "discourse/helpers/i18n";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import ComboBox from "select-kit/components/combo-box";
import { fn, hash } from "@ember/helper";
import LoadMore from "discourse/components/load-more";
import { LinkTo } from "@ember/routing";
import AvatarFlair from "discourse/components/avatar-flair";
import GroupInfo from "discourse/components/group-info";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import GroupMembershipButton from "discourse/components/group-membership-button";
import routeAction from "discourse/helpers/route-action";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
export default RouteTemplate(<template>{{#if (or @controller.loading @controller.groups.canLoadMore)}}
  {{hideApplicationFooter}}
{{/if}}

{{bodyClass "groups-page"}}

<PluginOutlet @name="before-groups-index-container" @connectorTagName="div" />

<section class="container groups-index">
  <div class="groups-header">
    {{#if @controller.currentUser.can_create_group}}
      <DButton @action={{@controller.new}} @icon="plus" @label="admin.groups.new.title" class="btn-default groups-header-new pull-right" />
    {{/if}}

    <div class="groups-header-filters">
      <Input @value={{readonly @controller.filter}} placeholder={{i18n "groups.index.all"}} class="groups-header-filters-name no-blur" {{on "input" (withEventValue @controller.onFilterChanged)}} @type="search" aria-description={{i18n "groups.index.search_results"}} />

      <ComboBox @value={{@controller.type}} @content={{@controller.types}} @onChange={{fn (mut @controller.type)}} @options={{hash clearable=true none="groups.index.filter"}} class="groups-header-filters-type" />
    </div>
  </div>

  {{#if @controller.groups}}
    <LoadMore @selector=".groups-boxes .group-box" @action={{action "loadMore"}}>
      <div class="container">
        <div class="groups-boxes">
          {{#each @controller.groups as |group|}}
            <LinkTo @route="group.members" @model={{group.name}} class="group-box" data-group-name={{group.name}}>
              <div class="group-box-inner">
                <div class="group-info-wrapper">
                  {{#if group.flair_url}}
                    <span class="group-avatar-flair">
                      <AvatarFlair @flairName={{group.name}} @flairUrl={{group.flair_url}} @flairBgColor={{group.flair_bg_color}} @flairColor={{group.flair_color}} />
                    </span>
                  {{/if}}

                  <span class="group-info">
                    <GroupInfo @group={{group}} />
                    <div class="group-user-count">{{icon "user"}}{{group.user_count}}</div>
                  </span>
                </div>

                <div class="group-description">{{htmlSafe group.bio_excerpt}}</div>

                <div class="group-membership">
                  <GroupMembershipButton @tagName @model={{group}} @showLogin={{routeAction "showLogin"}}>
                    {{#if group.is_group_owner}}
                      <span class="is-group-owner">
                        {{icon "shield-halved"}}
                        {{i18n "groups.index.is_group_owner"}}
                      </span>
                    {{else if group.is_group_user}}
                      <span class="is-group-member">
                        {{icon "check"}}
                        {{i18n "groups.index.is_group_user"}}
                      </span>
                    {{else if group.public_admission}}
                      {{i18n "groups.index.public"}}
                    {{else if group.isPrivate}}
                      {{icon "far-eye-slash"}}
                      {{i18n "groups.index.private"}}
                    {{else}}
                      {{#if group.automatic}}
                        {{i18n "groups.index.automatic"}}
                      {{else}}
                        {{icon "ban"}}
                        {{i18n "groups.index.closed"}}
                      {{/if}}
                    {{/if}}
                  </GroupMembershipButton>

                  <span>
                    <PluginOutlet @name="group-index-box-after" @connectorTagName="div" @outletArgs={{hash model=group}} />
                  </span>
                </div>
              </div>
            </LinkTo>
          {{/each}}
        </div>
      </div>
    </LoadMore>
    <ConditionalLoadingSpinner @condition={{@controller.groups.loadingMore}} />
  {{else}}
    <p role="status">{{i18n "groups.index.empty"}}</p>
  {{/if}}
</section>

<PluginOutlet @name="after-groups-index-container" @connectorTagName="div" /></template>)