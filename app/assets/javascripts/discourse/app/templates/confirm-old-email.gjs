import RouteTemplate from 'ember-route-template';
import DButton from "discourse/components/d-button";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><div id="simple-container">
  <div class="confirm-old-email">
    <h2>{{iN "user.change_email.authorizing_old.title"}}</h2>
    <p>
      {{#if @controller.model.old_email}}
        {{iN "user.change_email.authorizing_old.description"}}
      {{else}}
        {{iN "user.change_email.authorizing_old.description_add"}}
      {{/if}}
    </p>
    {{#if @controller.model.old_email}}
      <p>
        {{iN "user.change_email.authorizing_old.old_email" email=@controller.model.old_email}}
      </p>
    {{/if}}
    <p>
      {{iN "user.change_email.authorizing_old.new_email" email=@controller.model.new_email}}
    </p>
    <DButton @translatedLabel={{iN "user.change_email.confirm"}} class="btn-primary" @action={{@controller.confirm}} />
  </div>
</div></template>);