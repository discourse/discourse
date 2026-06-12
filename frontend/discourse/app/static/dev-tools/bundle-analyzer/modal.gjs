import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "./styles.css";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import { renderBundleAnalysis } from "./render";

export default class BundleAnalyzerModal extends Component {
  @tracked error;

  loadInto = async (element) => {
    try {
      // Computed at runtime rather than `new URL("./...", import.meta.url)` so
      // rolldown's resolveNewUrlToAsset doesn't try to resolve it as a build
      // asset. The JSON is emitted next to this chunk by bundle-analyzer-plugin.
      const url = import.meta.url.replace(/[^/]+$/, "bundle-analysis.json");
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      renderBundleAnalysis(element, await response.json());
    } catch (e) {
      this.error = e.message;
    }
  };

  <template>
    <DModal
      @title={{i18n "dev_tools.bundle_analyzer.title"}}
      @closeModal={{@closeModal}}
      class="bundle-analyzer-modal"
    >
      <:body>
        {{#if this.error}}
          <div class="ba-empty">
            {{i18n "dev_tools.bundle_analyzer.load_failed" error=this.error}}
          </div>
        {{else}}
          <div {{didInsert this.loadInto}}></div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
