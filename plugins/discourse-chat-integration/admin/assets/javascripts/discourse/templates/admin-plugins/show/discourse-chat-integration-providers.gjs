import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import NavItem from "discourse/components/nav-item";
import DMenu from "discourse/float-kit/components/d-menu";
import { i18n } from "discourse-i18n";

export default class DiscourseChatIntegrationProviders extends Component {
  @service router;

  isProviderActive = (providerName) => {
    return this.currentProvider === providerName;
  };

  get currentProvider() {
    return this.router.currentRoute?.params?.provider;
  }

  get enabledProviders() {
    return this.args.controller.model.content || [];
  }

  // Sorted by popularity (number of customer sites using each provider)
  get allProviders() {
    return [
      { name: "slack", setting: "chat_integration_slack_enabled" },
      { name: "discord", setting: "chat_integration_discord_enabled" },
      { name: "teams", setting: "chat_integration_teams_enabled" },
      { name: "telegram", setting: "chat_integration_telegram_enabled" },
      { name: "google", setting: "chat_integration_google_enabled" },
      { name: "matrix", setting: "chat_integration_matrix_enabled" },
      { name: "zulip", setting: "chat_integration_zulip_enabled" },
      { name: "mattermost", setting: "chat_integration_mattermost_enabled" },
      {
        name: "powerautomate",
        setting: "chat_integration_powerautomate_enabled",
      },
      { name: "gitter", setting: "chat_integration_gitter_enabled" },
      { name: "rocketchat", setting: "chat_integration_rocketchat_enabled" },
      { name: "guilded", setting: "chat_integration_guilded_enabled" },
      { name: "groupme", setting: "chat_integration_groupme_enabled" },
      { name: "flowdock", setting: "chat_integration_flowdock_enabled" },
      { name: "webex", setting: "chat_integration_webex_enabled" },
    ];
  }

  get disabledProviders() {
    const enabledNames = this.enabledProviders.map((p) => p.name);
    return this.allProviders.filter((p) => !enabledNames.includes(p.name));
  }

  @action
  configureProvider(provider) {
    this.router.transitionTo("adminSiteSettings", {
      queryParams: { filter: provider.setting },
    });
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/discourse-chat-integration"
      @label={{i18n "chat_integration.menu_title"}}
    />

    <div id="admin-plugin-chat" class="admin-detail">
      {{#if this.enabledProviders.length}}
        <div class="admin-nav-submenu">
          <ul class="nav nav-pills">
            {{#each this.enabledProviders as |provider|}}
              <NavItem
                @route="adminPlugins.show.discourse-chat-integration-providers.show"
                @routeParam={{provider.name}}
                @currentWhen={{this.isProviderActive provider.name}}
                @label={{concat
                  "chat_integration.provider."
                  provider.name
                  ".title"
                }}
              />
            {{/each}}
          </ul>
          {{#if this.disabledProviders.length}}
            <DMenu
              @identifier="chat-integration-add-provider"
              @icon="plus"
              @label={{i18n "chat_integration.add_provider"}}
              class="btn-default btn-small"
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#each this.disabledProviders as |provider|}}
                    <dropdown.item>
                      <DButton
                        @translatedLabel={{i18n
                          (concat
                            "chat_integration.provider." provider.name ".title"
                          )
                        }}
                        @action={{fn this.configureProvider provider}}
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  {{/each}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>

        {{outlet}}
      {{else}}
        <div class="admin-config-area">
          <div class="admin-config-area__empty-list">
            <p>{{i18n "chat_integration.no_providers_enabled"}}</p>
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
