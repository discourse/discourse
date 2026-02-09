import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import SiteSetting from "discourse/admin/models/site-setting";
import OnboardingStep from "discourse/components/admin-onboarding/step";
import DButton from "discourse/components/d-button";
import CreateInvite from "discourse/components/modal/create-invite";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy, defaultHomepage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

const STEPS = [
  class StartPosting extends OnboardingStep {
    static name = "start_posting";

    @service composer;
    @service appEvents;

    icon = "comments";
    icebreaker_topics = [
      "fun_facts",
      "coolest_thing_you_have_seen_today",
      "introduce_yourself",
      "what_is_your_favorite_food",
    ];

    constructor() {
      super(...arguments);
      this.appEvents.on("topic:created", this, this.checkIfPosted);
    }

    willDestroy() {
      super.willDestroy(...arguments);
      this.appEvents.off("topic:created", this, this.checkIfPosted);
    }

    checkIfPosted() {
      this.markAsCompleted();
    }

    @action
    async performAction() {
      const randomTopic =
        this.icebreaker_topics[
          Math.floor(Math.random() * this.icebreaker_topics.length)
        ];

      this.composer.openNewTopic({
        title: i18n(
          `admin_onboarding_banner.start_posting.icebreakers.${randomTopic}.title`
        ),
        body: i18n(
          `admin_onboarding_banner.start_posting.icebreakers.${randomTopic}.body`
        ),
      });
    }
  },
  class InviteCollaborators extends OnboardingStep {
    static name = "invite_collaborators";

    @service modal;
    @service appEvents;

    step = this.name;
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
        model: { invites: new TrackedArray() },
      });
    }
  },
  class SpreadTheWord extends OnboardingStep {
    static name = "spread_the_word";
    @service toasts;

    @tracked icon = "copy";

    @action
    performAction() {
      clipboardCopy(getAbsoluteURL("/"));

      this.toasts.success({
        data: {
          message: i18n(
            "admin_onboarding_banner.spread_the_word.copied_to_clipboard"
          ),
        },
      });

      this.markAsCompleted();
    }
  },
];

export default class AdminOnboardingBanner extends Component {
  @service siteSettings;
  @service currentUser;
  @service appEvents;
  @service keyValueStore;
  @service router;
  @service toasts;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "onboarding-step:completed",
      this,
      this.checkIfOnboardingIsComplete
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "onboarding-step:completed",
      this,
      this.checkIfOnboardingIsComplete
    );
  }

  get shouldDisplay() {
    if (!this.currentUser) {
      return false;
    }

    if (!this.siteSettings.enable_site_owner_onboarding) {
      return false;
    }

    if (!this.currentUser.admin) {
      return false;
    }

    const { currentRouteName } = this.router;
    return currentRouteName === `discovery.${defaultHomepage()}`;
  }

  checkIfOnboardingIsComplete() {
    const allStepsAreDone = STEPS.every(
      (Step) => !!this.keyValueStore.get(`onboarding_step_${Step.name}`)
    );

    if (allStepsAreDone) {
      this.endOnboarding({ skipped: false });
    }
  }

  @action
  async endOnboarding({ skipped = true } = {}) {
    await SiteSetting.update("enable_site_owner_onboarding", false);
    STEPS.forEach((Step) => {
      this.keyValueStore.remove(`onboarding_step_${Step.name}`);
    });

    const label = skipped
      ? "admin_onboarding_banner.skipped"
      : "admin_onboarding_banner.congrats_onboarding_complete";

    this.toasts.success({
      data: {
        message: i18n(label),
      },
    });
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
                <Step />
              {{/each}}
            </div>
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
