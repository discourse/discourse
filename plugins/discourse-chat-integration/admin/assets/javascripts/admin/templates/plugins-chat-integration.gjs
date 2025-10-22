import { concat } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import NavItem from "discourse/components/nav-item";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div id="admin-plugin-chat">
      <div class="admin-controls">
        <div class="admin-controls-chat-providers">
          <ul class="nav nav-pills">
            {{#each @controller.model as |provider|}}
              <NavItem
                @route="adminPlugins.chat-integration.provider"
                @routeParam={{provider.name}}
                @label={{concat
                  "chat_integration.provider."
                  provider.name
                  ".title"
                }}
              />
            {{/each}}
          </ul>
        </div>

        <DButton
          @icon="gear"
          @title="chat_integration.settings"
          @label="chat_integration.settings"
          @action={{routeAction "showSettings"}}
          class="chat-integration-settings-button"
        />
      </div>

      {{#unless @controller.model.totalRows}}
        {{i18n "chat_integration.no_providers"}}
      {{/unless}}

      {{outlet}}
    </div>
  </template>
);
