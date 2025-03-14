import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div id="simple-container">
      <div class="confirm-new-email">
        <h2>{{i18n "user.change_email.title"}}</h2>
        <p>
          {{#if @controller.model.old_email}}
            {{i18n "user.change_email.authorizing_new.description"}}
          {{else}}
            {{i18n "user.change_email.authorizing_new.description_add"}}
          {{/if}}
        </p>
        <p>{{@controller.model.new_email}}</p>
        <DButton
          @translatedLabel={{i18n "user.change_email.confirm"}}
          class="btn-primary"
          @action={{@controller.confirm}}
        />
      </div>
    </div>
  </template>
);
