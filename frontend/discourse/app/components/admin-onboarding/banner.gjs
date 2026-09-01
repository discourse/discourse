import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedArray, trackedSet } from "@ember/reactive/collections";
import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import PredefinedTopicsOptionsModal from "discourse/components/admin-onboarding/modal/predefined-topics-options";
import StartPostingOptions from "discourse/components/admin-onboarding/modal/start-posting-options";
import PredefinedTopicOption from "discourse/components/admin-onboarding/predefined-topics-option";
import OnboardingStep from "discourse/components/admin-onboarding/step";
import { logOnboardingEvent } from "discourse/lib/admin-onboarding";
import { showCreateInviteModal } from "discourse/lib/invite-modal";
import { applyValueTransformer } from "discourse/lib/transformer";
import { defaultHomepage } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const STEPS = [
  class SelectTheme extends OnboardingStep {
    static name = "select_theme";

    @service designWizard;

    icon = "paintbrush";

    #onComplete = () => this.markAsCompleted();

    constructor() {
      super(...arguments);
      this.designWizard.resumeAfterThemePreview({
        onComplete: this.#onComplete,
      });
    }

    // a homepage preview routes away from this component while the sheet lives on
    willDestroy() {
      super.willDestroy(...arguments);
      this.designWizard.clearCompletionCallback(this.#onComplete);
    }

    @action
    prefetch() {
      this.designWizard.prefetch();
    }

    @action
    performAction() {
      this.designWizard.start({ onComplete: this.#onComplete });
    }
  },
  class InviteCollaborators extends OnboardingStep {
    static name = "invite_collaborators";

    @service appEvents;

    icon = "paper-plane";

    constructor() {
      super(...arguments);
      this.appEvents.on("create-invite:saved", this, this.markAsCompleted);
    }

    willDestroy() {
      super.willDestroy(...arguments);
      this.appEvents.off("create-invite:saved", this, this.markAsCompleted);
    }

    @action
    performAction() {
      showCreateInviteModal(this, {
        model: { invites: trackedArray(), defaultRole: "admin" },
      });
    }
  },
  class StartPosting extends OnboardingStep {
    static name = "start_posting";

    @service composer;
    @service appEvents;
    @service modal;
    @service siteSettings;

    icon = "comments";

    constructor() {
      super(...arguments);

      this.appEvents.on("topic:created", this, this.completeStep);
      this.appEvents.on(
        "admin-onboarding:posting-complete",
        this,
        this.completeStep
      );
    }

    willDestroy() {
      super.willDestroy(...arguments);

      this.appEvents.off("topic:created", this, this.completeStep);
      this.appEvents.off(
        "admin-onboarding:posting-complete",
        this,
        this.completeStep
      );
    }

    completeStep() {
      return this.markAsCompleted();
    }

    showStartPostingOptions() {
      const options = applyValueTransformer(
        "admin-onboarding-start-posting-options",
        [PredefinedTopicOption]
      );

      if (options.length === 1) {
        // show predefined topics directly if it's the only option available
        return this.modal.show(PredefinedTopicsOptionsModal);
      }

      this.modal.show(StartPostingOptions, {
        model: {
          options,
          isStepComplete: this.completed,
        },
      });
    }

    openTopic(topicKey) {
      this.composer.openNewTopic({
        title: i18n(
          `admin_onboarding_banner.start_posting.icebreakers.${topicKey}.title`
        ),
        body: i18n(
          `admin_onboarding_banner.start_posting.icebreakers.${topicKey}.body`
        ),
      });
    }

    @action
    async performAction() {
      this.showStartPostingOptions();
    }
  },
];

export default class AdminOnboardingBanner extends Component {
  @service appEvents;
  @service currentUser;
  @service keyValueStore;
  @service router;
  @service toasts;

  @tracked dismissed = false;
  @tracked minimized = false;
  // the key value store isn't reactive, but the progress count must be
  completedStepNames = trackedSet(
    STEPS.filter(
      (Step) => !!this.keyValueStore.get(`onboarding_step_${Step.name}`)
    ).map((Step) => Step.name)
  );

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "onboarding-step:completed",
      this,
      this.markStepCompleted
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "onboarding-step:completed",
      this,
      this.markStepCompleted
    );
  }

  get shouldDisplay() {
    if (this.dismissed) {
      return false;
    }

    if (!this.currentUser?.show_site_owner_onboarding) {
      return false;
    }

    const { currentRouteName } = this.router;
    return currentRouteName === `discovery.${defaultHomepage()}`;
  }

  get completedSteps() {
    return this.completedStepNames.size;
  }

  @action
  markStepCompleted(name) {
    this.completedStepNames.add(name);
  }

  @action
  async checkIfOnboardingIsComplete() {
    const allStepsAreDone = STEPS.every(
      (Step) => !!this.keyValueStore.get(`onboarding_step_${Step.name}`)
    );

    if (allStepsAreDone) {
      await this.endOnboarding({ skipped: false });
    }
  }

  @action
  minimize() {
    this.minimized = !this.minimized;
  }

  @action
  async endOnboarding({ skipped = true } = {}) {
    await SiteSetting.update("enable_site_owner_onboarding", false);
    await logOnboardingEvent(skipped ? "dismissed" : "completed");
    this.dismissed = true;
    STEPS.forEach((Step) => {
      this.keyValueStore.remove(`onboarding_step_${Step.name}`);
    });
    this.completedStepNames.clear();

    if (!skipped) {
      this.toasts.success({
        data: {
          message: i18n("admin_onboarding_banner.congrats_onboarding_complete"),
        },
      });
    }
  }

  <template>
    {{#if this.shouldDisplay}}
      <div class="admin-onboarding-banner">
        <div class="admin-onboarding-banner__wrap">
          <div class="admin-onboarding-banner__header">
            <div class="admin-onboarding-banner__header-text">
              <span class="admin-onboarding-banner__title">
                {{dIcon "list" class="admin-onboarding-banner__title-icon"}}
                {{i18n "admin_onboarding_banner.launch_in_easy_steps"}}
              </span>
              {{#if this.minimized}}
                <span class="admin-onboarding-banner__subtitle">
                  {{i18n
                    "admin_onboarding_banner.launch_in_easy_steps_subtitle"
                    (hash
                      completed_steps=this.completedSteps
                      step_count=STEPS.length
                    )
                  }}
                </span>
              {{/if}}
            </div>
            <div class="admin-onboarding-banner__header-actions">
              <DButton
                class="btn no-text btn-transparent btn-minimize"
                @action={{this.minimize}}
                @ariaLabel={{if
                  this.minimized
                  "admin_onboarding_banner.expand"
                  "admin_onboarding_banner.collapse"
                }}
                @icon={{if this.minimized "angle-down" "angle-up"}}
              />
              <DButton
                class="btn no-text btn-transparent btn-close"
                @action={{this.endOnboarding}}
                @ariaLabel="admin_onboarding_banner.dismiss"
                @icon="xmark"
              />
            </div>
          </div>
          {{#unless this.minimized}}
            <div class="admin-onboarding-banner__content">
              <div class="admin-onboarding-banner__steps">
                {{#each STEPS as |Step|}}
                  <Step @onCompleted={{this.checkIfOnboardingIsComplete}} />
                {{/each}}
              </div>
            </div>
          {{/unless}}
        </div>
      </div>
    {{/if}}
  </template>
}
