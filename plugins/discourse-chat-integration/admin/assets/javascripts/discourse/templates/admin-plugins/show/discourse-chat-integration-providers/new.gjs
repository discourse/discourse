import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import AdminSectionLandingItem from "discourse/admin/components/admin-section-landing-item";
import AdminSectionLandingWrapper from "discourse/admin/components/admin-section-landing-wrapper";
import BackButton from "discourse/components/back-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import SetupProvider from "../../../../components/modal/setup-provider.gjs";

export default class DiscourseChatIntegrationProvidersNew extends Component {
  @service dialog;
  @service modal;
  @service router;
  @service toasts;

  get providers() {
    return (this.args.model.disabled_providers || []).map((provider) => ({
      ...provider,
      title: i18n(`chat_integration.provider.${provider.name}.title`),
      description: i18n(
        provider.additional_site_settings_required
          ? "chat_integration.new_provider.requires_token"
          : "chat_integration.new_provider.no_token"
      ),
    }));
  }

  @action
  async setupProvider(provider) {
    if (provider.additional_site_settings_required) {
      const closeData = await this.modal.show(SetupProvider, {
        model: { provider },
      });
      if (closeData?.setupCompleted) {
        await this.#showProvider(provider);
      }
      return;
    }

    this.dialog.confirm({
      message: i18n("chat_integration.confirm_setup_provider", {
        provider: provider.title,
      }),
      didConfirm: async () => {
        try {
          await ajax(
            "/admin/plugins/discourse-chat-integration/setup-provider",
            {
              type: "POST",
              data: { provider: { name: provider.name } },
            }
          );
          this.toasts.success({
            data: {
              message: i18n("chat_integration.setup_provider_modal.success", {
                provider: provider.title,
              }),
            },
            duration: "short",
          });
          await this.#showProvider(provider);
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  // The provider list is loaded by the parent route, so it has to be refreshed
  // before the newly enabled provider can be shown.
  async #showProvider(provider) {
    await this.router.refresh();
    this.router.transitionTo(
      "adminPlugins.show.discourse-chat-integration-providers.edit",
      provider.name
    );
  }

  <template>
    <DBreadcrumbsItem
      @label={{i18n "chat_integration.add_provider"}}
      @path="/admin/plugins/discourse-chat-integration/providers/new"
    />

    <div class="admin-detail chat-integration-provider-new">
      <BackButton
        @label="chat_integration.back_to_providers"
        @route="adminPlugins.show.discourse-chat-integration-providers.index"
      />

      <DPageSubheader
        @descriptionLabel={{i18n "chat_integration.new_provider.description"}}
        @titleLabel={{i18n "chat_integration.new_provider.title"}}
      />

      {{#if this.providers.length}}
        <AdminSectionLandingWrapper class="chat-integration-provider-new__list">
          {{#each this.providers as |provider|}}
            <AdminSectionLandingItem
              class={{dConcatClass
                "chat-integration-provider-new__item"
                (concat "--" provider.name)
              }}
              data-provider={{provider.name}}
              @descriptionLabelTranslated={{provider.description}}
              @titleLabelTranslated={{provider.title}}
            >
              <:buttons as |buttons|>
                <buttons.Default
                  class="chat-integration-provider-new__setup"
                  @action={{fn this.setupProvider provider}}
                  @icon="plus"
                  @label="chat_integration.new_provider.setup"
                />
              </:buttons>
            </AdminSectionLandingItem>
          {{/each}}
        </AdminSectionLandingWrapper>
      {{else}}
        <AdminConfigAreaEmptyList
          @emptyLabel="chat_integration.new_provider.all_enabled"
        />
      {{/if}}
    </div>
  </template>
}
