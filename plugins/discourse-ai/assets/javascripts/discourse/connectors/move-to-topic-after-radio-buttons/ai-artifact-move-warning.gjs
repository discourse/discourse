import Component from "@glimmer/component";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import { i18n } from "discourse-i18n";

export default class AiArtifactMoveWarning extends Component {
  static shouldRender({ topic }, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled &&
      siteSettings.ai_artifact_security !== "disabled" &&
      topic?.is_bot_pm
    );
  }

  <template>
    <DFlashMessage
      class="ai-artifact-move-warning"
      @flash={{i18n "discourse_ai.ai_artifact.move_warning"}}
      @type="warning"
    />
  </template>
}
