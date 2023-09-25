import RouteTemplate from "ember-route-template";
import WizardStep from "../components/wizard-step";

export default RouteTemplate(<template>
  <WizardStep
    @step={{@controller.step}}
    @wizard={{@controller.wizard}}
    @goNext={{@controller.goNext}}
    @goBack={{@controller.goBack}}
  />
</template>);
