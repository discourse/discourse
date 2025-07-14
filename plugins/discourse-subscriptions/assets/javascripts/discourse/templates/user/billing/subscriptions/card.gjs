import RouteTemplate from "ember-route-template";
import SaveControls from "discourse/components/save-controls";
import { i18n } from "discourse-i18n";
import SubscribeCard from "../../../../components/subscribe-card";

export default RouteTemplate(
  <template>
    <h3>{{i18n
        "discourse_subscriptions.user.subscriptions.update_card.heading"
        sub_id=@controller.model
      }}</h3>

    <div class="form-vertical">
      <div class="control-group">
        <SubscribeCard
          @cardElement={{@controller.cardElement}}
          class="input-xxlarge"
        />
      </div>

      <SaveControls
        @action={{@controller.updatePaymentMethod}}
        @saved={{@controller.saved}}
        @saveDisabled={{@controller.loading}}
      />
    </div>
  </template>
);
