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
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import SetupProvider from "../../../components/modal/setup-provider";

export default class DiscourseChatIntegrationProviders extends Component {
  @service router;
  @service modal;
  @service dialog;
  @service toasts;

  isProviderActive = (providerName) => {
    return this.currentProvider === providerName;
  };

  constructor() {
    super(...arguments);
  }

  get currentProvider() {
    return this.router.currentRoute?.params?.provider;
  }

  // Sorted by popularity (number of customer sites using each provider)
  get allProviders() {
    const providers = (
      this.args.controller.model.disabled_providers || []
    ).concat(this.args.controller.model.enabled_providers || []);
    return providers;
  }

  get enabledProviders() {
    return this.args.controller.model.enabled_providers || [];
  }

  get disabledProviders() {
    return this.args.controller.model.disabled_providers || [];
  }

  get popularProviders() {
    return this.disabledProviders.slice(0, 4);
  }

  get otherProviders() {
    return this.disabledProviders.slice(4);
  }

  providerTitle(provider) {
    return i18n(`chat_integration.provider.${provider.name}.title`);
  }

  @action
  async configureProvider(provider, menu = null) {
    const disabledProvider =
      this.disabledProviders.find((p) => p.name === provider.name) ?? provider;

    if (provider.additional_site_settings_required) {
      this.openProviderSetupModal(disabledProvider);
      menu?.close();
    } else {
      this.dialog.confirm({
        message: i18n("chat_integration.confirm_setup_provider", {
          provider: this.providerTitle(disabledProvider),
        }),
        didConfirm: async () => {
          try {
            await ajax(
              "/admin/plugins/discourse-chat-integration/setup-provider",
              {
                type: "POST",
                data: {
                  provider: {
                    name: disabledProvider.name,
                  },
                },
              }
            );
            this.toasts.success({
              data: {
                message: i18n("chat_integration.setup_provider_modal.success", {
                  provider: this.providerTitle(disabledProvider),
                }),
              },
              duration: "short",
            });
            this.navigateToProvider(disabledProvider);
          } catch (error) {
            popupAjaxError(error);
          }
        },
      });
    }
  }

  @action
  async openProviderSetupModal(provider) {
    const closeData = await this.modal.show(SetupProvider, {
      model: {
        provider: Object.assign({}, provider, {
          title: this.providerTitle(provider),
        }),
      },
    });

    if (closeData?.setupCompleted) {
      await this.navigateToProvider(provider);
    }
  }

  @action
  async navigateToProvider(provider) {
    await this.router.refresh();
    this.router.transitionTo(
      "adminPlugins.show.discourse-chat-integration-providers.show",
      provider.name
    );
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
              <:content as |menu|>
                <DropdownMenu as |dropdown|>
                  {{#each this.disabledProviders as |provider|}}
                    <dropdown.item>
                      <DButton
                        @translatedLabel={{i18n
                          (concat
                            "chat_integration.provider." provider.name ".title"
                          )
                        }}
                        @action={{fn this.configureProvider provider menu}}
                        class={{concatClass
                          "btn-transparent"
                          "chat-integration-add-provider-button"
                          (concat "--" provider.name)
                        }}
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
                  class={{concatClass
                    "btn-default"
                    "chat-integration-popular-provider-setup"
                    (concat "--" provider.name)
                  }}
                />
              {{/each}}
              {{#if this.otherProviders.length}}
                <DMenu
                  @identifier="chat-integration-more-providers"
                  @icon="ellipsis"
                  @label={{i18n "chat_integration.more_providers"}}
                  class="btn-default chat-integration-more-providers-setup"
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
                            class={{concatClass
                              "btn-transparent"
                              "chat-integration-more-providers-setup"
                              (concat "--" provider.name)
                            }}
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
