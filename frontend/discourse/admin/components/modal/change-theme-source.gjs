import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ChangeThemeSourceModal extends Component {
  @tracked publicKey = null;
  @tracked loading = false;
  @tracked generateNewKey = false;
  @tracked remoteUrl = this.args.model.theme.remote_theme?.remote_url || "";

  @cached
  get data() {
    return {
      remoteUrl: this.args.model.theme.remote_theme?.remote_url || "",
      branch: this.args.model.theme.remote_theme?.branch || "",
    };
  }

  get showPublicKey() {
    return this.remoteUrl?.match?.(/^ssh:\/\/.+@.+$|.+@.+:.+$/);
  }

  get hasExistingPrivateKey() {
    return this.args.model.theme.remote_theme?.has_private_key;
  }

  get showKeySection() {
    return (
      this.showPublicKey && (this.generateNewKey || !this.hasExistingPrivateKey)
    );
  }

  @action
  onRemoteUrlChange(value) {
    this.remoteUrl = value;
  }

  @action
  async generatePublicKey() {
    try {
      const pair = await ajax("/admin/themes/generate_key_pair", {
        type: "POST",
      });
      this.publicKey = pair.public_key;
    } catch (err) {
      popupAjaxError(err);
    }
  }

  @action
  toggleGenerateNewKey() {
    this.generateNewKey = !this.generateNewKey;
    if (!this.generateNewKey) {
      this.publicKey = null;
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  async onFormSubmit(data) {
    this.loading = true;
    try {
      const requestData = {
        remote_url: data.remoteUrl,
        branch: data.branch || null,
      };

      if (this.publicKey) {
        requestData.public_key = this.publicKey;
      }

      const result = await ajax(
        `/admin/themes/${this.args.model.theme.id}/source`,
        {
          type: "PUT",
          data: requestData,
        }
      );

      this.args.model.onSuccess?.(result.theme);
      this.args.closeModal();
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @bodyClass="change-theme-source"
      class="admin-change-theme-source-modal"
      @title={{i18n "admin.customize.theme.change_source.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <ConditionalLoadingSection
          @isLoading={{this.loading}}
          @title={{i18n "admin.customize.theme.change_source.updating"}}
        >
          <Form
            @data={{this.data}}
            @onSubmit={{this.onFormSubmit}}
            @onRegisterApi={{this.registerApi}}
            as |form|
          >
            <form.Field
              @name="remoteUrl"
              @type="input"
              @title={{i18n
                "admin.customize.theme.change_source.repository_url"
              }}
              @format="full"
              @validation="required"
              @onSet={{this.onRemoteUrlChange}}
              as |field|
            >
              <field.Control
                placeholder="https://github.com/user/repo.git"
                class="repo-url"
              />
            </form.Field>

            <form.Field
              @name="branch"
              @type="input"
              @title={{i18n "admin.customize.theme.change_source.branch"}}
              @format="full"
              as |field|
            >
              <field.Control placeholder="main" class="branch" />
            </form.Field>

            {{#if this.showPublicKey}}
              <div class="ssh-key-section">
                {{#if this.hasExistingPrivateKey}}
                  <div class="existing-key-notice">
                    {{i18n
                      "admin.customize.theme.change_source.has_existing_key"
                    }}
                  </div>
                  <DButton
                    @action={{this.toggleGenerateNewKey}}
                    @label={{if
                      this.generateNewKey
                      "admin.customize.theme.change_source.keep_existing_key"
                      "admin.customize.theme.change_source.generate_new_key"
                    }}
                    class="btn-default"
                  />
                {{/if}}

                {{#if this.showKeySection}}
                  <div class="public-key">
                    <div class="label">
                      {{i18n "admin.customize.theme.public_key"}}
                    </div>
                    <div class="public-key-text-wrapper">
                      <textarea
                        class="public-key-value"
                        readonly="true"
                        {{didInsert this.generatePublicKey}}
                      >{{this.publicKey}}</textarea>
                      <CopyButton @selector="textarea.public-key-value" />
                    </div>
                  </div>
                {{/if}}
              </div>
            {{/if}}
          </Form>
        </ConditionalLoadingSection>
      </:body>
      <:footer>
        <DButton
          @action={{this.formApi.submit}}
          @disabled={{this.loading}}
          class="btn-primary"
          @label="admin.customize.theme.change_source.update"
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
