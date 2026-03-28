import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class SetupProvider extends Component {
  @service toasts;

  get providerName() {
    return i18n(
      `chat_integration.provider.${this.args.model.provider.name}.title`
    );
  }

  @action
  async save() {
    try {
      await ajax("/admin/plugins/discourse-chat-integration/setup-provider", {
        type: "POST",
        data: {
          provider: {
            name: this.args.model.provider.name,
          },
        },
      });
      this.toasts.success({
        data: {
          message: i18n("chat_integration.setup_provider_modal.success", {
            provider: this.providerName,
          }),
        },
        duration: "short",
      });
      this.args.closeModal({ setupCompleted: true });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      @title={{i18n
        "chat_integration.setup_provider_modal.title"
        provider=(i18n
          (concat "chat_integration.provider." @model.provider.name ".title")
        )
      }}
      @closeModal={{@closeModal}}
      id="chat-integration-setup-provider-modal"
      class="chat-integration-modal"
    >
      <:body>
        <p>{{i18n
            "chat_integration.setup_provider_modal.setup_instructions"
            provider=this.providerName
          }}

          {{#if @model.provider.setup_form_settings}}
            {{i18n
              "chat_integration.setup_provider_modal.setup_instructions_additional_details"
              provider=this.providerName
            }}
          {{/if}}
        </p>
        <Form @onSubmit={{this.save}} as |form|>
          <form.Object @name="provider_site_settings" as |providerSiteSettings|>
            {{#each @model.provider.setup_form_settings as |detail|}}
              <providerSiteSettings.Field
                @type="text"
                @name={{detail.name}}
                @title={{detail.title}}
                @description={{detail.description}}
              >
                <providerSiteSettings.Control />
              </providerSiteSettings.Field>
            {{/each}}
          </form.Object>

          <form.Actions>
            <form.Submit
              @label="chat_integration.setup_provider_modal.confirm_setup"
              class="btn-primary"
              id="save-rule"
            />
            <form.Button
              @label="cancel"
              @action={{@closeModal}}
              class="btn-default"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
