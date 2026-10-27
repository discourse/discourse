import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "./styles.css";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import Analysis from "./analysis.js";
import LoadedChunks from "./loaded-chunks.js";
import PluginsAnalysis from "./plugins-analysis.js";
import Report from "./report.gjs";
import ViewFilter from "./view-filter.js";

export default class BundleAnalyzerModal extends Component {
  @tracked analysis;
  @tracked plugins;
  @tracked error;
  @tracked pluginError;

  // Once per opening, not once per session: the numbers mislead every time.
  @tracked warningAccepted = false;

  view = new ViewFilter();

  // Resolved through the page's import map, which Rails rebuilds from what the
  // builds left on disk, so each specifier names the current report. Fetched
  // together, and either can be missing without taking the other down.
  load = async () => {
    const core = this.#fetch("discourse/bundle-analysis").then(
      (data) => (this.analysis = this.#prepare(new Analysis(data))),
      (e) => {
        if (!this.#destroyed) {
          this.error = e.message;
        }
      }
    );

    const plugins = this.#fetch("discourse/bundle-analysis-plugins").then(
      (data) => (this.plugins = this.#prepare(new PluginsAnalysis(data))),
      (e) => {
        if (!this.#destroyed) {
          this.pluginError = e.message;
        }
      }
    );

    await Promise.all([core, plugins]);
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

  // `DEBUG` cannot be named in the template: the compiler lists its scope as
  // object shorthand, and the macro replacing it rewrites the key as well.
  get showWarning() {
    return DEBUG && !this.warningAccepted;
  }

  @action
  acceptWarning() {
    this.warningAccepted = true;
  }

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
        {{#if this.showWarning}}
          <div class="ba-warning">
            <h2>{{i18n "dev_tools.bundle_analyzer.development_title"}}</h2>
            <p>{{i18n "dev_tools.bundle_analyzer.development_warning"}}</p>
            <DButton
              class="btn-primary"
              @action={{this.acceptWarning}}
              @label="dev_tools.bundle_analyzer.development_continue"
            />
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
