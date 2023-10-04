import Controller, { inject as controller } from "@ember/controller";

export default class extends Controller {
  @controller wizardStep;
  get showCanvas() {
    return this.wizardStep.get("step.id") === "ready";
  }
}
