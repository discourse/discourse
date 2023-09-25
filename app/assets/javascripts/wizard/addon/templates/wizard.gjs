import RouteTemplate from "ember-route-template";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import DiscourseLogo from "../components/discourse-logo";
import WizardCanvas from "../components/wizard-canvas";

export default RouteTemplate(<template>
  {{hideApplicationFooter}}
  <div id="wizard-main">
    {{#if @controller.showCanvas}}
      <WizardCanvas />
    {{/if}}

    <div class="discourse-logo">
      <DiscourseLogo />
    </div>

    {{outlet}}
  </div>
</template>);
