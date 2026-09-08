import { trustHTML } from "@ember/template";
import GroupInfo from "discourse/components/group-info";
import GroupMembershipButton from "discourse/components/group-membership-button";
import GroupNavigation from "discourse/components/group-navigation";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { and, or } from "discourse/truth-helpers";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="before-group-container"
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
            <DAvatarFlair
              @flairBgColor={{@controller.model.flair_bg_color}}
              @flairColor={{@controller.model.flair_color}}
              @flairName={{@controller.model.name}}
              @flairUrl={{or
                @controller.model.flair_icon
                @controller.model.flair_url
              }}
            />
          </div>
        {{/if}}

        <div class="group-info-names">
          <GroupInfo @group={{@controller.model}} />

          {{#if (and @controller.canManageGroup @controller.model.automatic)}}
            <DTooltip class="group-automatic-tooltip">
              <:trigger>
                {{dIcon "gear"}}
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
            @model={{@controller.model}}
            @showLogin={{routeAction "showLogin"}}
          />

          {{#if @controller.currentUser.admin}}
            {{#if @controller.model.automatic}}
              <DButton
                class="btn-default"
                @action={{@controller.toggleDeleteTooltip}}
                @icon="circle-question"
                @label="admin.groups.delete"
              />
            {{else}}
              <DButton
                class="btn-danger"
                data-test-selector="delete-group-button"
                @action={{@controller.destroyGroup}}
                @disabled={{@controller.destroying}}
                @icon="trash-can"
                @label="admin.groups.delete"
              />
            {{/if}}
          {{/if}}

          {{#if @controller.displayGroupMessageButton}}
            <DButton
              class="btn-primary group-message-button"
              @action={{@controller.messageGroup}}
              @icon="envelope"
              @label="groups.message"
            />
          {{/if}}
        </div>

        <PluginOutlet
          @connectorTagName="div"
          @name="group-details-after"
          @outletArgs={{lazyHash model=@controller.model}}
        />
      </div>

      {{#if @controller.model.bio_cooked}}
        <div class="group-bio">
          {{trustHTML @controller.model.bio_cooked}}
        </div>
      {{/if}}

    </div>

    <div class="user-content-wrapper">
      <section class="user-primary-navigation">
        <GroupNavigation
          @currentPath={{@controller.currentPath}}
          @group={{@controller.model}}
          @tabs={{@controller.tabs}}
        />
      </section>
      {{outlet}}
    </div>
  </div>
</template>
