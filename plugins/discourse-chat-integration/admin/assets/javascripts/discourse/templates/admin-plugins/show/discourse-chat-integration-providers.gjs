import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
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
      "slack",
      "discord",
      "teams",
      "telegram",
      "google",
      "matrix",
      "zulip",
      "mattermost",
      "powerautomate",
      "gitter",
      "rocketchat",
      "guilded",
      "groupme",
      "webex",
    ].map((name) => ({
      name,
      settingsFilter: `chat_integration_${name}`,
    }));
  }

  get disabledProviders() {
    const enabledNames = this.enabledProviders.map((p) => p.name);
    return this.allProviders.filter((p) => !enabledNames.includes(p.name));
  }

  get popularProviders() {
    return this.disabledProviders.slice(0, 4);
  }

  get otherProviders() {
    return this.disabledProviders.slice(4);
  }

  @action
  configureProvider(provider) {
    this.router.transitionTo("adminPlugins.show.settings", {
      queryParams: { filter: provider.settingsFilter },
    });
  }

  <template>
    <DBreadcrumbsItem
      @path="/admin/plugins/discourse-chat-integration/providers"
      @label={{i18n "chat_integration.nav.providers"}}
    />

    <div id="admin-plugin-chat-integration" class="admin-detail">
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
        <AdminConfigAreaEmptyList
          @emptyLabel="chat_integration.empty_state.title"
          class="discourse-chat-integration-providers-empty-list"
        >
          <p>{{i18n "chat_integration.empty_state.body"}}</p>
          {{#if this.disabledProviders.length}}
            <div class="chat-integration-providers-list">
              {{#each this.popularProviders as |provider|}}
                <DButton
                  @translatedLabel={{i18n
                    (concat "chat_integration.provider." provider.name ".title")
                  }}
                  @action={{fn this.configureProvider provider}}
                  class="btn-default"
                />
              {{/each}}
              {{#if this.otherProviders.length}}
                <DMenu
                  @identifier="chat-integration-more-providers"
                  @icon="ellipsis"
                  @label={{i18n "chat_integration.more_providers"}}
                  class="btn-default"
                >
                  <:content>
                    <DropdownMenu as |dropdown|>
                      {{#each this.otherProviders as |provider|}}
                        <dropdown.item>
                          <DButton
                            @translatedLabel={{i18n
                              (concat
                                "chat_integration.provider."
                                provider.name
                                ".title"
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
          {{/if}}
        </AdminConfigAreaEmptyList>
      {{/if}}
    </div>
  </template>
}
