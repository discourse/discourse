import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import WorkflowPublishState from "../../lib/workflows/publish-state";

export default class PublishBanner extends Component {
  @service dialog;

  #publishState = new WorkflowPublishState({
    workflow: this.args.workflow,
    dialog: this.dialog,
    onDiscard: this.args.onDiscard,
  });

  get showBanner() {
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
    {{#if this.showBanner}}
      <div class="workflows-publish-banner">
        <span class="workflows-publish-banner__body" role="status">
          <span class="workflows-publish-banner__icon">
            {{dIcon "triangle-exclamation"}}
          </span>
          <span class="workflows-publish-banner__text">
            <span class="workflows-publish-banner__title">
              {{i18n "discourse_workflows.unpublished_changes_message"}}
            </span>
            <span class="workflows-publish-banner__detail">
              {{i18n "discourse_workflows.unpublished_changes_message_detail"}}
            </span>
          </span>
        </span>

        <span class="workflows-publish-banner__actions">
          <DButton
            class="btn-primary btn-small workflows-publish-banner__btn"
            @action={{this.publish}}
            @translatedLabel={{i18n "discourse_workflows.publish"}}
          />

          {{#if this.showDiscardButton}}
            <DButton
              class="btn-default btn-small workflows-publish-banner__btn"
              @action={{this.discard}}
              @translatedLabel={{i18n "discourse_workflows.discard_changes"}}
            />
          {{/if}}
        </span>
      </div>
    {{/if}}
  </template>
}
