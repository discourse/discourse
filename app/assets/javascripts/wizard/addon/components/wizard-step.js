import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import { htmlSafe } from "@ember/template";
import { schedule } from "@ember/runloop";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

const alreadyWarned = {};

export default Component.extend({
  router: service(),
  dialog: service(),
  classNameBindings: [":wizard-container__step", "stepClass"],
  saving: null,

  didInsertElement() {
    this._super(...arguments);
    this.autoFocus();
  },

  @discourseComputed("step.index")
  showBackButton(index) {
    return index > 0;
  },

  @discourseComputed("step.displayIndex", "wizard.totalSteps")
  showNextButton(current, total) {
    if (this.showConfigureMore === true) {
      return false;
    }
    return current < total;
  },

  @discourseComputed("step.id")
  nextButtonLabel(step) {
    return `wizard.${step === "ready" ? "configure_more" : "next"}`;
  },

  @discourseComputed("step.id")
  nextButtonClass(step) {
    return step === "ready" ? "configure-more" : "next";
  },

  @discourseComputed("step.id")
  showConfigureMore(step) {
    return step === "ready";
  },

  @discourseComputed("step.id")
  showJumpInButton(step) {
    return ["ready", "styling", "branding"].includes(step);
  },

  @discourseComputed("step.id")
  jumpInButtonLabel(step) {
    return `wizard.${step === "ready" ? "jump_in" : "finish"}`;
  },

  @discourseComputed("step.id")
  jumpInButtonClass(step) {
    return step === "ready" ? "jump-in" : "finish";
  },

  @discourseComputed("step.id")
  showFinishButton(step) {
    return step === "corporate";
  },

  @discourseComputed("step.id")
  stepClass(step) {
    return step;
  },

  @discourseComputed("step.banner")
  bannerImage(bannerName) {
    if (!bannerName) {
      return;
    }
    return bannerName;
  },

  @discourseComputed()
  bannerAndDescriptionClass() {
    return `wizard-container__step-banner`;
  },

  @observes("step.id")
  _stepChanged() {
    this.set("saving", false);
    this.autoFocus();
  },

  keyPress(event) {
    if (event.key === "Enter") {
      if (this.showJumpInButton) {
        this.send("quit");
      } else {
        this.send("nextStep");
      }
    }
  },

  @discourseComputed("step.index", "wizard.totalSteps")
  barStyle(displayIndex, totalSteps) {
    let ratio = parseFloat(displayIndex) / parseFloat(totalSteps - 1);
    if (ratio < 0) {
      ratio = 0;
    }
    if (ratio > 1) {
      ratio = 1;
    }

    return htmlSafe(`width: ${ratio * 200}px`);
  },

  @discourseComputed("step.fields")
  includeSidebar(fields) {
    return !!fields.findBy("show_in_sidebar");
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
  quit(event) {
    event?.preventDefault();
    this.router.transitionTo("discovery.latest");
  },

  @action
  exitEarly(event) {
    event?.preventDefault();
    const step = this.step;
    step.validate();

    if (step.get("valid")) {
      this.set("saving", true);

      step
        .save()
        .then((response) => this.goNext(response))
        .finally(() => this.set("saving", false));
    } else {
      this.autoFocus();
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

    const step = this.step;
    const result = step.validate();

    if (result.warnings.length) {
      const unwarned = result.warnings.filter((w) => !alreadyWarned[w]);

      if (unwarned.length) {
        unwarned.forEach((w) => (alreadyWarned[w] = true));

        return this.dialog.confirm({
          message: unwarned.map((w) => I18n.t(`wizard.${w}`)).join("\n"),
          didConfirm: () => this.advance(),
        });
      }
    }

    if (step.get("valid")) {
      this.advance();
    } else {
      this.autoFocus();
    }
  },
});
