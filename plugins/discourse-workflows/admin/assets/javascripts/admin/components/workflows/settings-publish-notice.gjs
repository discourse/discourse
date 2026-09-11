import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import WorkflowPublishState from "../../lib/workflows/publish-state";

export default class SettingsPublishNotice extends Component {
  @service dialog;

  #publishState = new WorkflowPublishState({
    workflow: this.args.workflow,
    dialog: this.dialog,
  });

  get showNotice() {
    return this.#publishState.visible;
  }

  get showDiscardButton() {
    return this.#publishState.showDiscardButton;
  }

  @action
  async publish() {
    await this.#publishState.publish();
  }

  @action
  async discard() {
    await this.#publishState.discard();
  }

  <template>
    {{#if this.showNotice}}
      <div class="workflows-settings-publish-notice">
        <span class="workflows-settings-publish-notice__text" role="status">
          <span class="workflows-settings-publish-notice__icon">
            {{dIcon "triangle-exclamation"}}
          </span>
          <span class="workflows-settings-publish-notice__copy">
            <span class="workflows-settings-publish-notice__title">
              {{i18n "discourse_workflows.unpublished_changes_message"}}
            </span>
            <span class="workflows-settings-publish-notice__detail">
              {{i18n "discourse_workflows.unpublished_changes_message_detail"}}
            </span>
          </span>
        </span>

        <span class="workflows-settings-publish-notice__actions">
          <DButton
            class="btn-primary btn-small workflows-settings-publish-notice__btn"
            @action={{this.publish}}
            @translatedLabel={{i18n "discourse_workflows.publish"}}
          />

          {{#if this.showDiscardButton}}
            <DButton
              class="btn-default btn-small workflows-settings-publish-notice__btn"
              @action={{this.discard}}
              @translatedLabel={{i18n "discourse_workflows.discard_changes"}}
            />
          {{/if}}
        </span>
      </div>
    {{/if}}
  </template>
}
