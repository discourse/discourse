import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import I18n from "I18n";
import getUrl from "discourse-common/lib/get-url";
import { htmlSafe } from "@ember/template";
import { schedule } from "@ember/runloop";

const alreadyWarned = {};

export default Component.extend({
  classNames: ["wizard-step"],
  saving: null,

  init() {
    this._super(...arguments);
    this.set("stylingDropdown", {});
  },

  didInsertElement() {
    this._super(...arguments);
    this.autoFocus();
  },

  @discourseComputed("step.index")
  showQuitButton: (index) => index === 0,

  @discourseComputed("step.displayIndex", "wizard.totalSteps")
  showNextButton: (current, total) => current < total,

  @discourseComputed("step.displayIndex", "wizard.totalSteps")
  showDoneButton: (current, total) => current === total,

  @discourseComputed(
    "step.index",
    "step.displayIndex",
    "wizard.totalSteps",
    "wizard.completed"
  )
  showFinishButton: (index, displayIndex, total, completed) => {
    return index !== 0 && displayIndex !== total && completed;
  },

  @discourseComputed("step.index")
  showBackButton: (index) => index > 0,

  @discourseComputed("step.banner")
  bannerImage(src) {
    if (!src) {
      return;
    }
    return getUrl(`/images/wizard/${src}`);
  },

  @discourseComputed("step.id")
  bannerAndDescriptionClass(id) {
    return `wizard-banner-and-description wizard-banner-and-description-${id}`;
  },

  @observes("step.id")
  _stepChanged() {
    this.set("saving", false);
    this.autoFocus();
  },

  keyPress(event) {
    if (event.key === "Enter") {
      if (this.showDoneButton) {
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
        ".wizard-field.invalid:nth-of-type(1) .wizard-focusable"
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

  actions: {
    quit() {
      document.location = getUrl("/");
    },

    stylingDropdownChanged(id, value) {
      this.set("stylingDropdown", { id, value });
    },

    exitEarly() {
      const step = this.step;
      step.validate();

      if (step.get("valid")) {
        this.set("saving", true);

        step
          .save()
          .then(() => this.send("quit"))
          .finally(() => this.set("saving", false));
      } else {
        this.autoFocus();
      }
    },

    backStep() {
      if (this.saving) {
        return;
      }

      this.goBack();
    },

    nextStep() {
      if (this.saving) {
        return;
      }

      const step = this.step;
      const result = step.validate();

      if (result.warnings.length) {
        const unwarned = result.warnings.filter((w) => !alreadyWarned[w]);
        if (unwarned.length) {
          unwarned.forEach((w) => (alreadyWarned[w] = true));
          return window.bootbox.confirm(
            unwarned.map((w) => I18n.t(`wizard.${w}`)).join("\n"),
            I18n.t("no_value"),
            I18n.t("yes_value"),
            (confirmed) => {
              if (confirmed) {
                this.advance();
              }
            }
          );
        }
      }

      if (step.get("valid")) {
        this.advance();
      } else {
        this.autoFocus();
      }
    },
  },
});
