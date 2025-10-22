import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import { and, or } from "truth-helpers";
import AvatarFlair from "discourse/components/avatar-flair";
import DButton from "discourse/components/d-button";
import GroupInfo from "discourse/components/group-info";
import GroupMembershipButton from "discourse/components/group-membership-button";
import GroupNavigation from "discourse/components/group-navigation";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default RouteTemplate(
  <template>
    <span>
      <PluginOutlet
        @name="before-group-container"
        @connectorTagName="div"
        @outletArgs={{lazyHash group=@controller.model}}
      />
    </span>

    <div class="container group group-{{@controller.model.name}}">
      {{#if @controller.showTooltip}}
        <div class="group-delete-tooltip">
          <p>{{i18n "admin.groups.delete_automatic_group"}}</p>
        </div>
      {{/if}}

      <div class="group-details-container">
        <div class="group-info">
          {{#if
            (or
              @controller.model.flair_icon
              @controller.model.flair_url
              @controller.model.flair_bg_color
            )
          }}
            <div class="group-avatar-flair">
              <AvatarFlair
                @flairName={{@controller.model.name}}
                @flairUrl={{or
                  @controller.model.flair_icon
                  @controller.model.flair_url
                }}
                @flairBgColor={{@controller.model.flair_bg_color}}
                @flairColor={{@controller.model.flair_color}}
              />
            </div>
          {{/if}}

          <div class="group-info-names">
            <GroupInfo @group={{@controller.model}} />

            {{#if (and @controller.canManageGroup @controller.model.automatic)}}
              <DTooltip class="group-automatic-tooltip">
                <:trigger>
                  {{icon "gear"}}
                  {{i18n "admin.groups.manage.membership.automatic"}}
                </:trigger>
                <:content>
                  {{i18n "admin.groups.manage.membership.automatic_tooltip"}}
                </:content>
              </DTooltip>
            {{/if}}
          </div>

          <div class="group-details-button">
            <GroupMembershipButton
              @tagName=""
              @model={{@controller.model}}
              @showLogin={{routeAction "showLogin"}}
            />

            {{#if @controller.currentUser.admin}}
              {{#if @controller.model.automatic}}
                <DButton
                  @action={{@controller.toggleDeleteTooltip}}
                  @icon="circle-question"
                  @label="admin.groups.delete"
                  class="btn-default"
                />
              {{else}}
                <DButton
                  @action={{@controller.destroyGroup}}
                  @disabled={{@controller.destroying}}
                  @icon="trash-can"
                  @label="admin.groups.delete"
                  class="btn-danger"
                  data-test-selector="delete-group-button"
                />
              {{/if}}
            {{/if}}

            {{#if @controller.displayGroupMessageButton}}
              <DButton
                @action={{@controller.messageGroup}}
                @icon="envelope"
                @label="groups.message"
                class="btn-primary group-message-button"
              />
            {{/if}}
          </div>

          <PluginOutlet
            @name="group-details-after"
            @connectorTagName="div"
            @outletArgs={{lazyHash model=@controller.model}}
          />
        </div>

        {{#if @controller.model.bio_cooked}}
          <div class="group-bio">
            {{htmlSafe @controller.model.bio_cooked}}
          </div>
        {{/if}}

      </div>

      <div class="user-content-wrapper">
        <section class="user-primary-navigation">
          <GroupNavigation
            @group={{@controller.model}}
            @currentPath={{@controller.currentPath}}
            @tabs={{@controller.tabs}}
          />
        </section>
        {{outlet}}
      </div>
    </div>
  </template>
);
