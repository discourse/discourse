import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { trackedArray, trackedSet } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import SiteSetting from "discourse/admin/models/site-setting";
import AgentPanel from "discourse/components/admin-onboarding/agent-panel";
import OnboardingStep from "discourse/components/admin-onboarding/step";
import {
  AGENT_TAB_HIDDEN_KEY,
  CONNECT_AGENT_STEP,
  CREATE_CATEGORY_STEP,
  isOnboardingStepCompleted,
  logOnboardingEvent,
  markOnboardingStepCompleted,
  onboardingStepKey,
  STEP_COMPLETED_CHANNEL,
} from "discourse/lib/admin-onboarding";
import { homepagePath } from "discourse/lib/homepage-router-overrides";
import { showCreateInviteModal } from "discourse/lib/invite-modal";
import { applyValueTransformer } from "discourse/lib/transformer";
import { defaultHomepage } from "discourse/lib/utilities";
import Site from "discourse/models/site";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

const DEFAULT_LOCATION = "above_main_container";

const StepList = <template>
  <div class="admin-onboarding-banner__steps">
    {{#each @steps as |Step|}}
      <Step @onCompleted={{@onCompleted}} />
    {{/each}}
  </div>
</template>;

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
  class CreateCategory extends OnboardingStep {
    static name = CREATE_CATEGORY_STEP;

    @service categoryTypeChooser;

    icon = "folder-open";

    @action
    performAction() {
      this.categoryTypeChooser.createCategory();
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
];

export default class AdminOnboardingBanner extends Component {
  @service appEvents;
  @service currentUser;
  @service keyValueStore;
  @service messageBus;
  @service router;
  @service siteSettings;
  @service toasts;

  @tracked activeTab = "steps";
  @tracked
  agentConnected =
    !!this.currentUser?.admin_onboarding_completed_steps?.includes(
      CONNECT_AGENT_STEP
    );
  @tracked agentTabHidden = !!this.keyValueStore.get(AGENT_TAB_HIDDEN_KEY);
  @tracked dismissed = false;
  @tracked minimized = false;
  // the key value store isn't reactive, but the progress count must be
  completedStepNames = trackedSet(
    this.steps
      .filter((Step) => isOnboardingStepCompleted(this, Step.name))
      .map((Step) => Step.name)
  );

  #completion;
  #heightContainer;

  #onStepCompleted = ({ step }) => {
    if (step === CONNECT_AGENT_STEP) {
      this.agentConnected = true;
      return;
    }

    if (!this.steps.some((Step) => Step.name === step)) {
      return;
    }

    markOnboardingStepCompleted(this, step);

    // a hidden banner checks when it shows again
    if (this.shouldDisplay) {
      this.checkIfOnboardingIsComplete();
    }
  };

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "onboarding-step:completed",
      this,
      this.markStepCompleted
    );

    if (this.currentUser?.show_site_owner_onboarding) {
      this.messageBus.subscribe(
        STEP_COMPLETED_CHANNEL,
        this.#onStepCompleted,
        this.currentUser.admin_onboarding_channel_position
      );
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "onboarding-step:completed",
      this,
      this.markStepCompleted
    );
    this.messageBus.unsubscribe(STEP_COMPLETED_CHANNEL, this.#onStepCompleted);
  }

  get #currentHomepage() {
    const routeName = this.router.currentRouteName;
    return (Site.current()?.homepage_choices ?? []).find(
      (choice) =>
        routeName === `discovery.${choice}` ||
        routeName?.startsWith(`${choice}.`)
    );
  }

  // Where the banner renders. A customization can return a location of its
  // own and render the banner there, as long as it passes a matching @location
  get location() {
    return applyValueTransformer(
      "admin-onboarding-banner-location",
      DEFAULT_LOCATION,
      { homepage: this.#currentHomepage ?? defaultHomepage() }
    );
  }

  // A bare <AdminOnboardingBanner> without @location renders regardless of the chosen location
  get matchesLocation() {
    return (
      this.args.location === undefined || this.args.location === this.location
    );
  }

  get shouldDisplay() {
    if (this.dismissed) {
      return false;
    }

    if (!this.currentUser?.show_site_owner_onboarding) {
      return false;
    }

    if (!this.matchesLocation) {
      return false;
    }

    const { currentRouteName, currentURL } = this.router;
    const path = currentURL?.split(/[?#]/)[0];

    return (
      this.#currentHomepage !== undefined ||
      currentRouteName === `discovery.${defaultHomepage()}` ||
      path === "/" ||
      path === homepagePath()
    );
  }

  /**
   * @returns {(typeof OnboardingStep)[]}
   */
  @cached
  get steps() {
    return applyValueTransformer("admin-onboarding-steps", [...STEPS], {
      homepage: this.#currentHomepage ?? defaultHomepage(),
    });
  }

  get completedSteps() {
    return this.completedStepNames.size;
  }

  get showAgentTab() {
    return this.siteSettings.mcp_server_enabled && !this.agentTabHidden;
  }

  @action
  hideAgentTab() {
    this.keyValueStore.set({ key: AGENT_TAB_HIDDEN_KEY, value: true });
    this.agentTabHidden = true;
    this.activeTab = "steps";

    // the hide button goes away with the tab, so focus would fall back to the page
    schedule("afterRender", () => {
      document
        .querySelector(".admin-onboarding-banner .onboarding-step__action .btn")
        ?.focus();
    });
  }

  @action
  markStepCompleted(name) {
    this.completedStepNames.add(name);
  }

  @action
  selectTab(key) {
    this.activeTab = key;
  }

  /**
   * Ends onboarding once every step is done. Also runs whenever the banner
   * appears, because steps can be finished away from it, e.g. by an AI agent.
   * Overlapping calls share one completion.
   */
  @action
  async checkIfOnboardingIsComplete() {
    const allStepsAreDone = this.steps.every((Step) =>
      isOnboardingStepCompleted(this, Step.name)
    );

    if (!allStepsAreDone || this.dismissed) {
      return;
    }

    this.#completion ??= this.endOnboarding({ skipped: false }).finally(
      () => (this.#completion = null)
    );
    await this.#completion;
  }

  @action
  minimize() {
    this.minimized = !this.minimized;
  }

  @action
  updateHeight(entries) {
    const element = entries[0].target;
    this.#heightContainer = element.parentElement;
    this.#heightContainer.style.setProperty(
      "--admin-onboarding-banner-height",
      `${element.getBoundingClientRect().height}px`
    );
  }

  @action
  clearHeight() {
    this.#heightContainer?.style.removeProperty(
      "--admin-onboarding-banner-height"
    );
    this.#heightContainer = undefined;
  }

  @action
  async endOnboarding({ skipped = true } = {}) {
    await SiteSetting.update("enable_site_owner_onboarding", false);
    await logOnboardingEvent(skipped ? "dismissed" : "completed");
    this.dismissed = true;
    this.steps.forEach((Step) => {
      this.keyValueStore.remove(onboardingStepKey(Step.name));
    });
    this.keyValueStore.remove(AGENT_TAB_HIDDEN_KEY);
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
      <div
        class="admin-onboarding-banner"
        {{dOnResize this.updateHeight}}
        {{willDestroy this.clearHeight}}
        {{didInsert this.checkIfOnboardingIsComplete}}
      >
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
                      step_count=this.steps.length
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
              {{#if this.showAgentTab}}
                <DTabs
                  class="admin-onboarding-banner__tabs"
                  @active={{this.activeTab}}
                  @label={{i18n "admin_onboarding_banner.tabs_label"}}
                  @onActivate={{this.selectTab}}
                  as |tabs|
                >
                  <tabs.Tab
                    @key="steps"
                    @label={{i18n "admin_onboarding_banner.step_by_step"}}
                  >
                    <StepList
                      @onCompleted={{this.checkIfOnboardingIsComplete}}
                      @steps={{this.steps}}
                    />
                  </tabs.Tab>
                  <tabs.Tab @key="agent">
                    <:label>
                      {{dIcon "robot"}}
                      {{i18n "admin_onboarding_banner.agent.tab"}}
                    </:label>
                    <:default>
                      <AgentPanel
                        @connected={{this.agentConnected}}
                        @onHide={{this.hideAgentTab}}
                      />
                    </:default>
                  </tabs.Tab>
                </DTabs>
              {{else}}
                <StepList
                  @onCompleted={{this.checkIfOnboardingIsComplete}}
                  @steps={{this.steps}}
                />
              {{/if}}
            </div>
          {{/unless}}
        </div>
      </div>
    {{/if}}
  </template>
}
