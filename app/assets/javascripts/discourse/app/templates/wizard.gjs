import RouteTemplate from "ember-route-template";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import DiscourseLogo from "discourse/static/wizard/components/discourse-logo";

export default RouteTemplate(<template>
  {{hideApplicationFooter}}
  <div id="wizard-main">
    <DiscourseLogo />

    {{outlet}}
  </div>
</template>);
