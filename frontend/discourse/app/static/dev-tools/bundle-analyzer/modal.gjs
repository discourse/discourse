import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "./styles.css";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import Analysis from "./analysis";
import LoadedChunks from "./loaded-chunks";
import PluginsAnalysis from "./plugins-analysis";
import Report from "./report";
import ViewFilter from "./view-filter";

export default class BundleAnalyzerModal extends Component {
  @tracked analysis;
  @tracked plugins;
  @tracked error;
  @tracked pluginError;

  // One filter behind both tabs, handed to each analysis as it is built.
  view = new ViewFilter();

  // Both reports are resolved through the page's import map, which Rails rebuilds
  // from the manifests on every render, so each names the current build.
  load = async () => {
    this.analysis = await this.#fetch("discourse/bundle-analysis").then(
      (data) => data && this.#prepare(new Analysis(data)),
      (e) => {
        this.error = e.message;
      }
    );

    // A plugin report only exists once plugins have been compiled, and its
    // absence should not take the core report down with it.
    this.plugins = await this.#fetch("discourse/bundle-analysis-plugins").then(
      (data) => data && this.#prepare(new PluginsAnalysis(data)),
      (e) => {
        this.pluginError = e.message;
      }
    );
  };

  #observers = [];
  #destroyed = false;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#destroyed = true;
    this.#observers.forEach((o) => o.teardown());
  }

  get ready() {
    return !!(this.analysis || this.plugins);
  }

  // Read here rather than in the template: the template compiler lists its
  // scope as object shorthand, and the macro that swaps `DEBUG` for a literal
  // would rewrite the key as well as the value.
  get developmentBuild() {
    return DEBUG;
  }

  // The graph answers every size question, so the graph is what holds the
  // reader's filter and the browser's record of what it fetched.
  #prepare(analysis) {
    if (this.#destroyed) {
      return null;
    }
    analysis.view = this.view;
    analysis.loaded = new LoadedChunks(analysis.chunks);
    this.#observers.push(analysis.loaded);
    return analysis;
  }

  async #fetch(specifier) {
    const response = await fetch(import.meta.resolve(specifier));
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return response.json();
  }

  <template>
    <DModal
      class="bundle-analyzer-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "dev_tools.bundle_analyzer.title"}}
    >
      <:body>
        {{#if this.developmentBuild}}
          {{! A development build is unminified and chunked differently, so its
              sizes describe nothing anyone ships. }}
          <div class="ba-empty">
            {{i18n "dev_tools.bundle_analyzer.production_only"}}
          </div>
        {{else}}
          <div {{didInsert this.load}}>
            {{#if this.error}}
              <div class="ba-empty">
                {{i18n
                  "dev_tools.bundle_analyzer.load_failed"
                  error=this.error
                }}
              </div>
            {{/if}}
            {{#if this.pluginError}}
              <div class="ba-empty">
                {{i18n
                  "dev_tools.bundle_analyzer.load_failed"
                  error=this.pluginError
                }}
              </div>
            {{/if}}
            {{#if this.ready}}
              <Report
                @core={{this.analysis}}
                @plugins={{this.plugins}}
                @view={{this.view}}
              />
            {{/if}}
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
