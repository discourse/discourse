import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import DesignWizardControls, {
  STEPS,
} from "discourse/components/design-wizard/controls";
import { isTesting } from "discourse/lib/environment";
import { prefersReducedMotion } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class DesignWizardPanel extends Component {
  @service designWizard;
  @service dialog;

  element;

  get stepProgress() {
    return i18n("design_wizard.step_progress", {
      current: this.designWizard.stepIndex + 1,
      total: STEPS.length,
    });
  }

  @action
  minimize() {
    this.designWizard.setMinimized(true);
  }

  @action
  restore() {
    this.designWizard.setMinimized(false);
    schedule("afterRender", () => {
      this.element
        ?.querySelector(".design-wizard__minimize")
        ?.focus({ preventScroll: true });
    });
  }

  @action
  registerElement(element) {
    this.element = element;
  }

  @action
  async close() {
    // steps are saved as they are completed, so closing a run that changed the
    // live site is a decision rather than a dismissal
    if (this.designWizard.needsCloseConfirmation) {
      const canRevert = this.designWizard.canRevert;

      this.dialog.alert({
        message: i18n(
          canRevert
            ? "design_wizard.close.message"
            : "design_wizard.close.message_without_revert"
        ),
        buttons: [
          {
            label: i18n("design_wizard.close.keep"),
            class: "btn-primary",
            action: () => this.dismiss(),
          },
          {
            label: i18n("design_wizard.close.continue_editing"),
            class: "btn-flat",
          },
          // last, so the destructive choice is not the one landed on by accident
          ...(canRevert
            ? [
                {
                  label: i18n("design_wizard.close.revert"),
                  class: "btn-danger",
                  action: () => this.designWizard.revert(),
                },
              ]
            : []),
        ],
      });
      return;
    }

    await this.dismiss();
  }

  @action
  async dismiss() {
    if (this.element && !isTesting() && !prefersReducedMotion()) {
      const slideOut =
        getComputedStyle(this.element)
          .getPropertyValue("--design-wizard-slide-out")
          .trim() || "translateX(100%)";

      await this.element
        .animate([{ transform: "translate(0, 0)" }, { transform: slideOut }], {
          duration: 250,
          easing: "ease-in",
          fill: "forwards",
        })
        .finished.catch(() => {});
    }

    this.designWizard.stop();
  }

  <template>
    {{#if this.designWizard.active}}
      <aside
        aria-hidden={{if this.designWizard.minimized "true"}}
        aria-labelledby="design-wizard-title"
        class={{dConcatClass
          "design-wizard"
          (unless this.designWizard.animateEntrance "--no-entrance")
          (if this.designWizard.applyingTheme "--busy")
          (if this.designWizard.minimized "--minimized")
        }}
        id="design-wizard-panel"
        inert={{this.designWizard.minimized}}
        ...attributes
        {{didInsert this.registerElement}}
      >
        <div class="design-wizard__panel-actions">
          <DButton
            class="btn-transparent design-wizard__minimize"
            @action={{this.minimize}}
            @disabled={{this.designWizard.applyingTheme}}
            @icon="minus"
            @title="design_wizard.minimize"
          />
          <DButton
            class="btn-transparent design-wizard__close"
            @action={{this.close}}
            @icon="xmark"
            @title="modal.close"
          />
        </div>
        <DesignWizardControls />
      </aside>
      {{#if this.designWizard.minimized}}
        <DButton
          aria-controls="design-wizard-panel"
          class="btn-default design-wizard__restore"
          @action={{this.restore}}
          @ariaExpanded={{false}}
          @title="design_wizard.restore"
          {{dAutoFocus}}
        >
          <span class="design-wizard__restore-title">
            {{i18n "design_wizard.title"}}
          </span>
          {{#unless this.designWizard.showIntro}}
            <span class="design-wizard__restore-progress">
              {{this.stepProgress}}
            </span>
          {{/unless}}
          {{dIcon "chevron-up"}}
        </DButton>
      {{/if}}
    {{/if}}
  </template>
}
