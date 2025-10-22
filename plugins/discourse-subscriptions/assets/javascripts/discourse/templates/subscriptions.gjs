import RouteTemplate from "ember-route-template";
import LoginRequired from "../components/login-required";

export default RouteTemplate(
  <template>
    <div class="container">
      {{#if @controller.currentUser}}
        {{@controller.pricingTable}}
      {{else}}
        <LoginRequired />
      {{/if}}
    </div>
  </template>
);
