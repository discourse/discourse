import Component from "@ember/component";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import $ from "jquery";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":wizard-container__step", "stepClass"],
  saving: null,

  didInsertElement() {
    this._super(...arguments);
    this.autoFocus();
  },

  /**
    Step        Back Button?     Primary Action      Secondary Action
    ------------------------------------------------------------------
    First            No               Next                  N/A
    ------------------------------------------------------------------
    ...             Yes               Next                  N/A
    ------------------------------------------------------------------
    Ready           Yes              Jump In          Configure More
    ------------------------------------------------------------------
    ...             Yes               Next              Exit Setup
    ------------------------------------------------------------------
    Last            Yes              Jump In                N/A
    ------------------------------------------------------------------

    Back Button: without saving, go back to the last page
    Next Button: save, and if successful, go to the next page
    Configure More: re-skinned next button
    Exit Setup: without saving, go to the home page ("finish")
    Jump In: on the "ready" page, it exits the setup ("finish"), on the
    last page, it saves, and if successful, go to the home page
   */

  @discourseComputed("step.displayIndex", "wizard.steps.length")
  isFinalStep(current, total) {
    return current === total;
  },

  @discourseComputed("step.index")
  showBackButton(index) {
    return index > 0;
  },

  @discourseComputed("wizard", "step.index", "isFinalStep")
  showFinishButton(wizard, index, isFinalStep) {
    const ready = wizard.findStep("ready");
    const isReady = ready && index > ready.index;
    return isReady && !isFinalStep;
  },

  @discourseComputed("step.id")
  showConfigureMore(step) {
    return step === "ready";
  },

  @discourseComputed("step.id", "isFinalStep")
  showJumpInButton(step, isFinalStep) {
    return step === "ready" || isFinalStep;
  },

  @discourseComputed("step.id")
  stepClass(step) {
    return step;
  },

  @observes("step")
  _stepChanged() {
    this.set("saving", false);
    this.autoFocus();
  },

  keyPress(event) {
    if (event.key === "Enter") {
      if (this.showJumpInButton) {
        this.jumpIn();
      } else {
        this.nextStep();
      }
    }
  },

  @discourseComputed("step.fields")
  includeSidebar(fields) {
    return !!fields.findBy("showInSidebar");
  },

  autoFocus() {
    schedule("afterRender", () => {
      const $invalid = $(
        ".wizard-container__input.invalid:nth-of-type(1) .wizard-focusable"
      );

      if ($invalid.length) {
        return $invalid.focus();
      }

      $(".wizard-focusable:nth-of-type(1)").focus();
    });
  },

  advance() {
    this.set("saving", true);
    this.step
      .save()
      .then((response) => this.goNext(response))
      .finally(() => this.set("saving", false));
  },

  @action
  finish(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    this.goHome();
  },

  @action
  jumpIn(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    if (this.step.id === "ready") {
      this.finish();
    } else {
      this.nextStep();
    }
  },

  @action
  backStep(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    this.goBack();
  },

  @action
  nextStep(event) {
    event?.preventDefault();

    if (this.saving) {
      return;
    }

    if (this.step.validate()) {
      this.advance();
    } else {
      this.autoFocus();
    }
  },
});
