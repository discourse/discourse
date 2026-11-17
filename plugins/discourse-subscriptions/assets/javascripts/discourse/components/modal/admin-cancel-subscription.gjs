import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class AdminCancelSubscription extends Component {
  @tracked refund;

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n
        "discourse_subscriptions.user.subscriptions.operations.destroy.confirm"
      }}
    >
      <:body>
        <Input @checked={{this.refund}} @type="checkbox" />
        {{i18n "discourse_subscriptions.admin.ask_refund"}}
      </:body>
      <:footer>
        <DButton
          class="btn-danger"
          @action={{fn
            @model.cancelSubscription
            (hash
              subscription=@model.subscription
              refund=this.refund
              closeModal=@closeModal
            )
          }}
          @icon="xmark"
          @isLoading={{@model.subscription.loading}}
          @label="yes_value"
        />
        <DButton @action={{@closeModal}} @label="no_value" />
      </:footer>
    </DModal>
  </template>
}
