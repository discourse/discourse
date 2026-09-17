import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "./styles.css";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import Analysis from "./analysis";
import Report from "./report";

export default class BundleAnalyzerModal extends Component {
  @tracked analysis;
  @tracked error;

  load = async () => {
    try {
      // Computed at runtime rather than `new URL("./...", import.meta.url)` so
      // rolldown's resolveNewUrlToAsset doesn't try to resolve it as a build
      // asset. The JSON is emitted next to this chunk by bundle-analyzer-plugin.
      const url = import.meta.url.replace(
        /[^/]+$/,
        "bundle-analysis.digested.json"
      );
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      this.analysis = new Analysis(await response.json());
    } catch (e) {
      this.error = e.message;
    }
  };

  <template>
    <DModal
      class="bundle-analyzer-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "dev_tools.bundle_analyzer.title"}}
    >
      <:body>
        <div {{didInsert this.load}}>
          {{#if this.error}}
            <div class="ba-empty">
              {{i18n "dev_tools.bundle_analyzer.load_failed" error=this.error}}
            </div>
          {{else if this.analysis}}
            <Report @analysis={{this.analysis}} />
          {{/if}}
        </div>
      </:body>
    </DModal>
  </template>
}
