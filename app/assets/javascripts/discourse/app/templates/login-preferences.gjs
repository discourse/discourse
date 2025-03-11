import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="container">
      <h2>{{i18n "login.to_continue"}}</h2>

      <p style="margin-top: 1em">{{i18n "login.preferences"}}</p>

      <DButton
        @action={{routeAction "showLogin"}}
        @label="log_in"
        class="btn-primary"
      />
    </div>
  </template>
);
