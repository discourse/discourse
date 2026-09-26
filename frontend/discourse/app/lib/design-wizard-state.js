import { tracked } from "@glimmer/tracking";

// Read at boot to decide whether the wizard panel loads.
class DesignWizardState {
  @tracked active = false;
}

export const designWizardState = new DesignWizardState();
