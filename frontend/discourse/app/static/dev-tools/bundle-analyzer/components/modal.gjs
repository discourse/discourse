import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "../styles.css";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import Analysis from "../models/analysis.js";
import LoadedChunks from "../models/loaded-chunks.js";
import PluginsAnalysis from "../models/plugins-analysis.js";
import ViewFilter from "../models/view-filter.js";
import Report from "./report.gjs";

export default class BundleAnalyzerModal extends Component {
  @tracked analysis;
  @tracked plugins;
  @tracked error;
  @tracked pluginError;

  // Once per opening, not once per session: the numbers mislead every time.
  @tracked warningAccepted = false;

  view = new ViewFilter();

  // Core and every plugin build write their own report, so the server lists the
  // ones it has and they are fetched from there. Either half can be missing
  // without taking the other down.
  load = async () => {
    let index;

    try {
      index = await this.#fetch(getURL("/bundle-analysis.json"));
    } catch (e) {
      if (!this.#destroyed) {
        this.error = e.message;
      }
      return;
    }

    const core = this.#fetch(index.core).then(
      (data) => (this.analysis = this.#prepare(new Analysis(data))),
      (e) => {
        if (!this.#destroyed) {
          this.error = e.message;
        }
      }
    );

    const plugins = Promise.all(
      index.plugins.map((url) => this.#fetch(url))
    ).then(
      (reports) =>
        (this.plugins = this.#prepare(
          new PluginsAnalysis({ plugins: reports })
        )),
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

  async #fetch(url) {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return response.json();
  }

  <template>
    <DModal
      class="bundle-analyzer-modal"
      @closeModal={{@closeModal}}
      @title="Bundle analysis"
    >
      <:body>
        {{#if this.showWarning}}
          <div class="ba-warning">
            <h2>Development build</h2>
            <p>Chunk splitting and sizes are completely different to production,
              and brotli sizes aren't available. Restart the server with
              EMBER_ENV=production.</p>
            <DButton
              class="btn-primary"
              @action={{this.acceptWarning}}
              @translatedLabel="Open analyzer anyway"
            />
          </div>
        {{else}}
          <div {{didInsert this.load}}>
            {{#if this.error}}
              <div class="ba-empty">
                Failed to load bundle-analysis.json:
                {{this.error}}
              </div>
            {{/if}}
            {{#if this.pluginError}}
              <div class="ba-empty">
                Failed to load bundle-analysis.json:
                {{this.pluginError}}
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
