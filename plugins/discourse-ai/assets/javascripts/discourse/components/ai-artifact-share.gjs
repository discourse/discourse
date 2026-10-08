import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import AiArtifactShareModal from "./modal/ai-artifact-share-modal";

export default class AiArtifactShare extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  @tracked allowed = false;
  @tracked share = null;

  get canCheckEligibility() {
    return (
      this.currentUser?.can_share_ai_bot_conversations &&
      this.siteSettings.discourse_ai_enabled &&
      this.siteSettings.ai_bot_enabled &&
      this.siteSettings.ai_artifact_security !== "disabled"
    );
  }

  @action
  async load() {
    if (!this.canCheckEligibility) {
      return;
    }
    try {
      const result = await ajax(
        `/discourse-ai/ai-bot/artifact-shares/eligibility/${this.args.artifactId}.json`
      );
      this.allowed = result.can_share;
      this.share = result.share;
    } catch {
      // Passive check: a failure leaves sharing hidden instead of interrupting the reader.
    }
  }

  @action
  showShare() {
    this.modal.show(AiArtifactShareModal, {
      model: {
        artifactId: this.args.artifactId,
        artifactVersion: this.args.artifactVersion,
        onShareChange: this.updateShare,
        share: this.share,
      },
    });
  }

  @action
  updateShare(share) {
    this.share = share;
  }

  <template>
    <div class="ai-artifact-share" {{didInsert this.load}}>
      {{#if this.allowed}}
        <DButton
          class="btn-transparent ai-artifact-share__toggle"
          @action={{this.showShare}}
          @icon="share"
          @label="discourse_ai.ai_artifact.share"
        />
      {{/if}}
    </div>
  </template>
}
