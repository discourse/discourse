import RouteTemplate from 'ember-route-template';
import DButton from "discourse/components/d-button";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template><div id="simple-container">
  <div class="confirm-new-email">
    <h2>{{iN "user.change_email.title"}}</h2>
    <p>
      {{#if @controller.model.old_email}}
        {{iN "user.change_email.authorizing_new.description"}}
      {{else}}
        {{iN "user.change_email.authorizing_new.description_add"}}
      {{/if}}
    </p>
    <p>{{@controller.model.new_email}}</p>
    <DButton @translatedLabel={{iN "user.change_email.confirm"}} class="btn-primary" @action={{@controller.confirm}} />
  </div>
</div></template>);