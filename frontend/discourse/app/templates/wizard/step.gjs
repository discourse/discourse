import WizardStep from "discourse/static/wizard/components/wizard-step";

const WizardStepWrapper = <template>
  <WizardStep @step={{@model.step}} @wizard={{@model.wizard}} />
</template>;

export default WizardStepWrapper;
