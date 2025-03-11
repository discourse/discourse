import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import SecondFactorInput from "discourse/components/second-factor-input";
import withEventValue from "discourse/helpers/with-event-value";
import {
  MAX_SECOND_FACTOR_NAME_LENGTH,
  SECOND_FACTOR_METHODS,
} from "discourse/models/user";
import { i18n } from "discourse-i18n";

export default class SecondFactorAddTotp extends Component {
  @tracked loading = false;
  @tracked secondFactorImage;
  @tracked secondFactorKey;
  @tracked showSecondFactorKey = false;
  @tracked errorMessage;
  @tracked secondFactorToken;

  maxSecondFactorNameLength = MAX_SECOND_FACTOR_NAME_LENGTH;
  totpType = SECOND_FACTOR_METHODS.TOTP;

  @action
  totpRequested() {
    this.args.model.secondFactor
      .createSecondFactorTotp()
      .then((response) => {
        if (response.error) {
          this.errorMessage = response.error;
          return;
        }

        this.errorMessage = null;
        this.secondFactorKey = response.key;
        this.secondFactorImage = response.qr;
      })
      .catch((error) => {
        this.args.closeModal();
        this.args.model.onError(error);
      })
      .finally(() => (this.loading = false));
  }

  @action
  enableShowSecondFactorKey(e) {
    e.preventDefault();
    e.stopImmediatePropagation();
    this.showSecondFactorKey = true;
  }

  @action
  enableSecondFactor() {
    if (!this.secondFactorToken || !this.secondFactorName) {
      this.errorMessage = i18n(
        "user.second_factor.totp.name_and_code_required_error"
      );
      return;
    }
    this.loading = true;
    this.args.model.secondFactor
      .enableSecondFactorTotp(this.secondFactorToken, this.secondFactorName)
      .then((response) => {
        if (response.error) {
          this.errorMessage = response.error;
          return;
        }
        this.args.model.markDirty();
        this.errorMessage = null;
        this.args.closeModal();
        if (this.args.model.enforcedSecondFactor) {
          window.location.reload();
        }
      })
      .catch((error) => this.args.model.onError(error))
      .finally(() => (this.loading = false));
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "user.second_factor.totp.add"}}
      {{didInsert this.totpRequested}}
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.errorMessage}}
            <div class="control-group">
              <div class="controls">
                <div class="alert alert-error">{{this.errorMessage}}</div>
              </div>
            </div>
          {{/if}}

          <div class="control-group">
            <div class="controls">
              {{htmlSafe (i18n "user.second_factor.enable_description")}}
            </div>
          </div>

          <div class="control-group">
            <div class="controls">
              <div class="qr-code">
                <img src={{htmlSafe this.secondFactorImage}} />
              </div>
              <p>
                {{#if this.showSecondFactorKey}}
                  <div class="second-factor-key">
                    {{this.secondFactorKey}}
                  </div>
                {{else}}
                  <a
                    href
                    class="show-second-factor-key"
                    {{on "click" this.enableShowSecondFactorKey}}
                  >{{i18n "user.second_factor.show_key_description"}}</a>
                {{/if}}
              </p>
            </div>
          </div>

          <div class="control-group">
            <label class="control-label input-prepend">{{i18n
                "user.second_factor.name"
              }}</label>
            <div class="controls">
              <input
                {{on "input" (withEventValue (fn (mut this.secondFactorName)))}}
                value={{this.secondFactorName}}
                type="text"
                placeholder={{i18n "user.second_factor.totp.default_name"}}
                maxlength={{this.maxSecondFactorNameLength}}
                id="second-factor-name"
              />
            </div>

            <label class="control-label input-prepend">
              {{i18n "user.second_factor.label"}}
            </label>
            <div class="controls">
              <SecondFactorInput
                {{on
                  "input"
                  (withEventValue (fn (mut this.secondFactorToken)))
                }}
                @secondFactorMethod={{this.totpType}}
                value={{this.secondFactorToken}}
                placeholder="123456"
                id="second-factor-token"
              />
            </div>
          </div>

          <div class="control-group">
            <div class="controls">
              <DButton
                class="btn-primary add-totp"
                @action={{this.enableSecondFactor}}
                @label="enable"
              />
            </div>
          </div>
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
