import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import SiteSetting from "discourse/admin/models/site-setting";
import DButton from "discourse/components/d-button";
import CreateInvite from "discourse/components/modal/create-invite";
import bodyClass from "discourse/helpers/body-class";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy, defaultHomepage } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

class OnboardingStep extends Component {
  static name() {
    throw new Error("Name is required for OnboardingStep");
  }

  @service keyValueStore;
  @service appEvents;

  @tracked
  completed = this.keyValueStore.get(`onboarding_step_${this.name}`) || false;

  i18nKey = "admin_onboarding_banner.";

  get name() {
    return this.constructor.name;
  }

  get icon() {
    throw new Error("Icon is required for OnboardingStep");
  }

  @action
  performAction() {
    throw new Error("performAction is required for OnboardingStep");
  }

  markAsCompleted() {
    this.keyValueStore.set({
      key: `onboarding_step_${this.name}`,
      value: true,
    });
    this.completed = true;
    this.appEvents.trigger(`onboarding-step:completed`, this.name);
  }

  <template>
    <div class={{"onboarding-step"}} id={{this.name}}>
      <div class="onboarding-step__checkbox">
        <span
          class={{if
            this.completed
            "chcklst-box checked fa fa-square-check-o"
            "chcklst-box fa fa-square-o"
          }}
        />
        <span>{{i18n (concat this.i18nKey this.name ".title")}}</span>
      </div>

      <div class="onboarding-step__description">
        <span>
          {{i18n (concat this.i18nKey this.name ".description")}}
        </span>
      </div>

      <div class="onboarding-step__action">
        <DButton
          @icon={{this.icon}}
          @label={{(concat this.i18nKey this.name ".action")}}
          @action={{this.performAction}}
          class="btn btn-default"
        />
      </div>
    </div>
  </template>
}

const STEPS = [
  class StartPosting extends OnboardingStep {
    static name = "start_posting";

    @service composer;
    @service appEvents;

    icon = "comments";

    constructor() {
      super(...arguments);
      this.appEvents.on("topic:created", this, this.checkIfPosted);
    }

    willDestroyElement() {
      super.willDestroyElement(...arguments);
      this.appEvents.off("topic:created", this, this.checkIfPosted);
    }

    checkIfPosted() {
      this.markAsCompleted();
    }

    @action
    async performAction() {
      this.composer.openNewTopic({
        title: i18n("admin_onboarding_banner.start_posting.icebreaker_title"),
        body: i18n("admin_onboarding_banner.start_posting.icebreaker_post"),
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

    willDestroyElement() {
      super.willDestroyElement(...arguments);
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

    @tracked icon = "copy";

    @action
    performAction() {
      clipboardCopy(getAbsoluteURL("/"));

      this.icon = "check";
      setTimeout(() => {
        this.icon = "copy";
      }, 2000);

      this.markAsCompleted();
    }
  },
];

export default class AdminOnboardingBanner extends Component {
  @service siteSettings;
  @service currentUser;
  @service appEvents;
  @service keyValueStore;
  @service dialog;
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

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.appEvents.off(
      "onboarding-step:completed",
      this,
      this.checkIfOnboardingIsComplete
    );
  }

  get bodyClasses() {}

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
      this.endOnboarding({ showConfirmation: false });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("admin_onboarding_banner.congrats_onboarding_complete"),
        },
      });
    }
  }

  @action
  async endOnboarding({ showConfirmation = true } = {}) {
    if (showConfirmation) {
      const confirmed = await this.dialog.yesNoConfirm({
        message: i18n("admin_onboarding_banner.confirm_cancel_onboarding"),
      });
      if (!confirmed) {
        return;
      }
    }

    await SiteSetting.update("enable_site_owner_onboarding", false);
    STEPS.forEach((Step) => {
      this.keyValueStore.remove(`onboarding_step_${Step.name}`);
    });
  }

  <template>
    {{bodyClass this.bodyClasses}}
    {{#if this.shouldDisplay}}
      <div class={{"admin-onboarding-banner"}}>
        <div class={{"admin-onboarding-banner__wrap"}}>
          <div class={{"admin-onboarding-banner__header"}}>
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
          <div class={{"admin-onboarding-banner__content"}}>
            <div class={{"admin-onboarding-banner__steps"}}>
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
