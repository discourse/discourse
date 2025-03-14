import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div id="simple-container">
      <div class="confirm-old-email">
        <h2>{{i18n "user.change_email.authorizing_old.title"}}</h2>
        <p>
          {{#if @controller.model.old_email}}
            {{i18n "user.change_email.authorizing_old.description"}}
          {{else}}
            {{i18n "user.change_email.authorizing_old.description_add"}}
          {{/if}}
        </p>
        {{#if @controller.model.old_email}}
          <p>
            {{i18n
              "user.change_email.authorizing_old.old_email"
              email=@controller.model.old_email
            }}
          </p>
        {{/if}}
        <p>
          {{i18n
            "user.change_email.authorizing_old.new_email"
            email=@controller.model.new_email
          }}
        </p>
        <DButton
          @translatedLabel={{i18n "user.change_email.confirm"}}
          class="btn-primary"
          @action={{@controller.confirm}}
        />
      </div>
    </div>
  </template>
);
