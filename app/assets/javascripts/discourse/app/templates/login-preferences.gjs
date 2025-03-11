import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import i18n from "discourse/helpers/i18n";
import routeAction from "discourse/helpers/route-action";

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
