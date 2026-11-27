import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import getURL, { getAbsoluteURL } from "discourse/lib/get-url";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AdminOnboardingAgentPanel extends Component {
  @service toasts;

  @tracked promptExpanded = false;

  promptId = `admin-onboarding-agent-prompt-${guidFor(this)}`;

  get prompt() {
    return i18n("admin_onboarding_banner.agent.prompt", {
      site_url: getAbsoluteURL("/").replace(/\/$/, ""),
      mcp_url: getAbsoluteURL("/mcp"),
      instructions_url: getAbsoluteURL("/agent-setup.md"),
    });
  }

  get safetyNote() {
    return trustHTML(
      i18n("admin_onboarding_banner.agent.safety_note", {
        preferences_url: getURL("/my/preferences/security"),
      })
    );
  }

  /**
   * Once an agent is connected, the prompt is only needed to start over, so
   * it stays folded away until the admin asks for it.
   */
  get showPrompt() {
    return !this.args.connected || this.promptExpanded;
  }

  @action
  async copyPrompt() {
    await clipboardCopy(this.prompt);
    this.toasts.success({
      duration: "short",
      data: {
        message: i18n("admin_onboarding_banner.agent.prompt_copied"),
      },
    });
  }

  @action
  togglePrompt() {
    this.promptExpanded = !this.promptExpanded;
  }

  <template>
    <div
      class={{dConcatClass
        "admin-onboarding-agent"
        (if @connected "--connected")
      }}
    >
      <div class="admin-onboarding-agent__summary">
        <div class="admin-onboarding-agent__status" role="status">
          {{#if @connected}}
            <p class="admin-onboarding-agent__connected">
              {{dIcon "circle-check"}}
              {{i18n "admin_onboarding_banner.agent.connected"}}
            </p>
          {{/if}}
        </div>

        {{#if @connected}}
          <DButton
            class="btn-transparent btn-small admin-onboarding-agent__toggle-prompt"
            @action={{this.togglePrompt}}
            @ariaControls={{this.promptId}}
            @ariaExpanded={{this.promptExpanded}}
            @icon={{if this.promptExpanded "angle-up" "angle-down"}}
            @label={{if
              this.promptExpanded
              "admin_onboarding_banner.agent.hide_prompt"
              "admin_onboarding_banner.agent.show_prompt"
            }}
          />
        {{/if}}
      </div>

      <div class="admin-onboarding-agent__setup" id={{this.promptId}}>
        {{#if this.showPrompt}}
          <p class="admin-onboarding-agent__intro">
            {{i18n "admin_onboarding_banner.agent.intro"}}
          </p>

          <div class="admin-onboarding-agent__prompt">
            <p class="admin-onboarding-agent__prompt-text">{{this.prompt}}</p>
            <DButton
              class="btn-primary btn-small admin-onboarding-agent__copy-prompt"
              @action={{this.copyPrompt}}
              @icon="copy"
              @label="admin_onboarding_banner.agent.copy_prompt"
            />
          </div>
        {{/if}}
      </div>

      <div class="admin-onboarding-agent__footer">
        <p class="admin-onboarding-agent__note">{{this.safetyNote}}</p>
        <DButton
          class="btn-transparent btn-small admin-onboarding-agent__hide"
          @action={{@onHide}}
          @label="admin_onboarding_banner.agent.hide"
        />
      </div>
    </div>
  </template>
}
