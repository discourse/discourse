import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AssociateAccountConfirm extends Component {
  @service router;
  @service currentUser;

  @tracked flash;

  @action
  async finishConnect() {
    try {
      const result = await ajax({
        url: `/associate/${encodeURIComponent(this.args.model.token)}`,
        type: "POST",
      });

      if (result.success) {
        this.router.transitionTo(
          "preferences.account",
          this.currentUser.findDetails()
        );
        this.args.closeModal();
      } else {
        this.flash = result.error;
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n
        "user.associated_accounts.confirm_modal_title"
        provider=(i18n (concat "login." @model.provider_name ".name"))
      }}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
    >
      <:body>
        {{#if @model.existing_account_description}}
          <p>
            {{i18n
              "user.associated_accounts.confirm_description.disconnect"
              provider=(i18n (concat "login." @model.provider_name ".name"))
              account_description=@model.existing_account_description
            }}
          </p>
        {{/if}}

        <p>
          {{#if @model.account_description}}
            {{i18n
              "user.associated_accounts.confirm_description.account_specific"
              provider=(i18n (concat "login." @model.provider_name ".name"))
              account_description=@model.account_description
            }}
          {{else}}
            {{i18n
              "user.associated_accounts.confirm_description.generic"
              provider=(i18n (concat "login." @model.provider_name ".name"))
            }}
          {{/if}}
        </p>
      </:body>

      <:footer>
        <DButton
          @label="user.associated_accounts.connect"
          @action={{this.finishConnect}}
          @icon="plug"
          class="btn-primary"
        />
        <DButton
          @label="user.associated_accounts.cancel"
          @action={{@closeModal}}
        />
      </:footer>
    </DModal>
  </template>
}
