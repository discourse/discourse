import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import PredefinedTopicsOptionsModal from "discourse/components/admin-onboarding/modal/predefined-topics-options";
import StartPostingOptions from "discourse/components/admin-onboarding/modal/start-posting-options";
import ThemePickerModal from "discourse/components/admin-onboarding/modal/theme-picker";
import PredefinedTopicOption from "discourse/components/admin-onboarding/predefined-topics-option";
import OnboardingStep from "discourse/components/admin-onboarding/step";
import CreateInvite from "discourse/components/modal/create-invite";
import { applyValueTransformer } from "discourse/lib/transformer";
import { defaultHomepage } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const STEPS = [
  class SelectTheme extends OnboardingStep {
    static name = "select_theme";

    @service modal;

    icon = "paintbrush";

    @action
    performAction() {
      this.modal.show(ThemePickerModal, {
        model: { onThemeSelected: () => this.markAsCompleted() },
      });
    }
  },
  class InviteCollaborators extends OnboardingStep {
    static name = "invite_collaborators";

    @service modal;
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
      this.modal.show(CreateInvite, {
        model: { invites: trackedArray() },
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
  @service currentUser;
  @service keyValueStore;
  @service router;
  @service toasts;

  @tracked dismissed = false;

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
  async endOnboarding({ skipped = true } = {}) {
    await SiteSetting.update("enable_site_owner_onboarding", false);
    this.dismissed = true;
    STEPS.forEach((Step) => {
      this.keyValueStore.remove(`onboarding_step_${Step.name}`);
    });

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
            <h2>
              {{i18n
                "admin_onboarding_banner.launch_in_easy_steps"
                (hash step_count=STEPS.length)
              }}
            </h2>
            <DButton
              @action={{this.endOnboarding}}
              @icon="xmark"
              class="btn no-text btn-transparent btn-close"
            />
          </div>
          <div class="admin-onboarding-banner__content">
            <div class="admin-onboarding-banner__steps">
              {{#each STEPS as |Step|}}
                <Step @onCompleted={{this.checkIfOnboardingIsComplete}} />
              {{/each}}
            </div>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
