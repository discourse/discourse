import { concat } from "@ember/helper";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import DNavItem from "discourse/ui-kit/d-nav-item";
import { i18n } from "discourse-i18n";

export default <template>
  <div id="admin-plugin-chat">
    <div class="admin-controls">
      <div class="admin-controls-chat-providers">
        <ul class="nav nav-pills">
          {{#each @controller.model.content as |provider|}}
            <DNavItem
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
