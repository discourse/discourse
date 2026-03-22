import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import CopyButton from "discourse/components/copy-button";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class ChangeThemeSourceModal extends Component {
  @tracked remoteUrl = this.args.model.theme.remote_theme?.remote_url || "";
  @tracked branch = this.args.model.theme.remote_theme?.branch || "";
  @tracked publicKey = null;
  @tracked loading = false;
  @tracked generateNewKey = false;

  keyGenUrl = "/admin/themes/generate_key_pair";

  get showPublicKey() {
    return this.remoteUrl?.match?.(/^ssh:\/\/.+@.+$|.+@.+:.+$/);
  }

  get hasExistingPrivateKey() {
    return this.args.model.theme.remote_theme?.has_private_key;
  }

  get submitDisabled() {
    return this.loading || !this.remoteUrl?.trim();
  }

  get showKeySection() {
    return (
      this.showPublicKey && (this.generateNewKey || !this.hasExistingPrivateKey)
    );
  }

  @action
  async generatePublicKey() {
    try {
      const pair = await ajax(this.keyGenUrl, { type: "POST" });
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
  async updateSource() {
    this.loading = true;
    try {
      const data = {
        remote_url: this.remoteUrl,
        branch: this.branch || null,
      };

      if (this.publicKey) {
        data.public_key = this.publicKey;
      }

      const result = await ajax(
        `/admin/themes/${this.args.model.theme.id}/source`,
        {
          type: "PUT",
          data,
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
          <div class="inputs">
            <div class="repo">
              <div class="label">
                {{i18n "admin.customize.theme.change_source.repository_url"}}
              </div>
              <input
                type="text"
                {{on "input" (withEventValue (fn (mut this.remoteUrl)))}}
                value={{this.remoteUrl}}
                placeholder="https://github.com/user/repo.git"
              />
            </div>

            <div class="branch">
              <div class="label">
                {{i18n "admin.customize.theme.change_source.branch"}}
              </div>
              <input
                type="text"
                {{on "input" (withEventValue (fn (mut this.branch)))}}
                value={{this.branch}}
                placeholder="main"
              />
            </div>

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
                        {{on
                          "input"
                          (withEventValue (fn (mut this.publicKey)))
                        }}
                        value={{this.publicKey}}
                        {{didInsert this.generatePublicKey}}
                      />
                      <CopyButton @selector="textarea.public-key-value" />
                    </div>
                  </div>
                {{/if}}
              </div>
            {{/if}}
          </div>
        </ConditionalLoadingSection>
      </:body>
      <:footer>
        <DButton
          @action={{this.updateSource}}
          @disabled={{this.submitDisabled}}
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
