import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "./styles.css";
import DModal from "discourse/ui-kit/d-modal";
import DTabs from "discourse/ui-kit/d-tabs";
import { i18n } from "discourse-i18n";
import Analysis from "./analysis";
import PluginsAnalysis from "./plugins-analysis";
import PluginsReport from "./plugins-report";
import Report from "./report";
import ViewFilter from "./view-filter";

export default class BundleAnalyzerModal extends Component {
  @tracked analysis;
  @tracked plugins;
  @tracked error;
  @tracked pluginError;
  @tracked tab = "core";

  // One filter behind both tabs, handed to each analysis as it is built.
  view = new ViewFilter();

  // Both reports are resolved through the page's import map, which Rails rebuilds
  // from the manifests on every render, so each names the current build.
  load = async () => {
    this.analysis = await this.#fetch("discourse/bundle-analysis").then(
      (data) => data && this.#withView(new Analysis(data)),
      (e) => {
        this.error = e.message;
      }
    );

    // A plugin report only exists once plugins have been compiled, and its
    // absence should not take the core report down with it.
    this.plugins = await this.#fetch("discourse/bundle-analysis-plugins").then(
      (data) => data && this.#withView(new PluginsAnalysis(data)),
      (e) => {
        this.pluginError = e.message;
      }
    );
  };

  // Read here rather than in the template: the template compiler lists its
  // scope as object shorthand, and the macro that swaps `DEBUG` for a literal
  // would rewrite the key as well as the value.
  get developmentBuild() {
    return DEBUG;
  }

  @action
  setTab(key) {
    this.tab = key;
  }

  @action
  toggleOnlyLoaded() {
    this.view.onlyLoaded = !this.view.onlyLoaded;
  }

  #withView(analysis) {
    analysis.view = this.view;
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
            <DTabs
              @active={{this.tab}}
              @label={{i18n "dev_tools.bundle_analyzer.title"}}
              @onActivate={{this.setTab}}
              as |tabs|
            >
              <tabs.Tab
                @key="core"
                @label={{i18n "dev_tools.bundle_analyzer.core"}}
              >
                {{#if this.error}}
                  <div class="ba-empty">
                    {{i18n
                      "dev_tools.bundle_analyzer.load_failed"
                      error=this.error
                    }}
                  </div>
                {{else if this.analysis}}
                  <Report
                    @analysis={{this.analysis}}
                    @toggleOnlyLoaded={{this.toggleOnlyLoaded}}
                    @view={{this.view}}
                  />
                {{/if}}
              </tabs.Tab>

              <tabs.Tab
                @key="plugins"
                @label={{i18n "dev_tools.bundle_analyzer.plugins"}}
              >
                {{#if this.pluginError}}
                  <div class="ba-empty">
                    {{i18n
                      "dev_tools.bundle_analyzer.load_failed"
                      error=this.pluginError
                    }}
                  </div>
                {{else if this.plugins}}
                  <PluginsReport
                    @analysis={{this.plugins}}
                    @toggleOnlyLoaded={{this.toggleOnlyLoaded}}
                    @view={{this.view}}
                  />
                {{/if}}
              </tabs.Tab>
            </DTabs>
          </div>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
