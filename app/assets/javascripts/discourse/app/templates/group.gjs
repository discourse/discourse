import RouteTemplate from 'ember-route-template'
import PluginOutlet from "discourse/components/plugin-outlet";
import { hash } from "@ember/helper";
import iN from "discourse/helpers/i18n";
import or from "truth-helpers/helpers/or";
import AvatarFlair from "discourse/components/avatar-flair";
import GroupInfo from "discourse/components/group-info";
import and from "truth-helpers/helpers/and";
import DTooltip from "float-kit/components/d-tooltip";
import dIcon from "discourse/helpers/d-icon";
import GroupMembershipButton from "discourse/components/group-membership-button";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/components/d-button";
import htmlSafe from "discourse/helpers/html-safe";
import GroupNavigation from "discourse/components/group-navigation";
export default RouteTemplate(<template><span>
  <PluginOutlet @name="before-group-container" @connectorTagName="div" @outletArgs={{hash group=@controller.model}} />
</span>

<div class="container group group-{{@controller.model.name}}">
  {{#if @controller.showTooltip}}
    <div class="group-delete-tooltip">
      <p>{{iN "admin.groups.delete_automatic_group"}}</p>
    </div>
  {{/if}}

  <div class="group-details-container">
    <div class="group-info">
      {{#if (or @controller.model.flair_icon @controller.model.flair_url @controller.model.flair_bg_color)}}
        <div class="group-avatar-flair">
          <AvatarFlair @flairName={{@controller.model.name}} @flairUrl={{or @controller.model.flair_icon @controller.model.flair_url}} @flairBgColor={{@controller.model.flair_bg_color}} @flairColor={{@controller.model.flair_color}} />
        </div>
      {{/if}}

      <div class="group-info-names">
        <GroupInfo @group={{@controller.model}} />

        {{#if (and @controller.canManageGroup @controller.model.automatic)}}
          <DTooltip class="group-automatic-tooltip">
            <:trigger>
              {{dIcon "gear"}}
              {{iN "admin.groups.manage.membership.automatic"}}
            </:trigger>
            <:content>
              {{iN "admin.groups.manage.membership.automatic_tooltip"}}
            </:content>
          </DTooltip>
        {{/if}}
      </div>

      <div class="group-details-button">
        <GroupMembershipButton @tagName @model={{@controller.model}} @showLogin={{routeAction "showLogin"}} />

        {{#if @controller.currentUser.admin}}
          {{#if @controller.model.automatic}}
            <DButton @action={{@controller.toggleDeleteTooltip}} @icon="circle-question" @label="admin.groups.delete" class="btn-default" />
          {{else}}
            <DButton @action={{@controller.destroyGroup}} @disabled={{@controller.destroying}} @icon="trash-can" @label="admin.groups.delete" class="btn-danger" data-test-selector="delete-group-button" />
          {{/if}}
        {{/if}}

        {{#if @controller.displayGroupMessageButton}}
          <DButton @action={{@controller.messageGroup}} @icon="envelope" @label="groups.message" class="btn-primary group-message-button" />
        {{/if}}
      </div>

      <PluginOutlet @name="group-details-after" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
    </div>

    {{#if @controller.model.bio_cooked}}
      <div class="group-bio">
        {{htmlSafe @controller.model.bio_cooked}}
      </div>
    {{/if}}

  </div>

  <div class="user-content-wrapper">
    <section class="user-primary-navigation">
      <GroupNavigation @group={{@controller.model}} @currentPath={{@controller.currentPath}} @tabs={{@controller.tabs}} />
    </section>
    {{outlet}}
  </div>
</div></template>)