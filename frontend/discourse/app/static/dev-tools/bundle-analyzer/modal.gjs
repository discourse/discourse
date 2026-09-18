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
      // Resolved through the page's import map, which Rails rebuilds from the
      // manifest on every render, so this always names the current build's
      // report rather than whichever one the browser has cached.
      const response = await fetch(
        import.meta.resolve("discourse/bundle-analysis")
      );
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
