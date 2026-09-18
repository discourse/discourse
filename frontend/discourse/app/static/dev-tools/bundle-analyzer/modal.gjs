import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import "./styles.css";
import DModal from "discourse/ui-kit/d-modal";
import DTabs from "discourse/ui-kit/d-tabs";
import { i18n } from "discourse-i18n";
import Analysis from "./analysis";
import PluginsReport from "./plugins-report";
import Report from "./report";

export default class BundleAnalyzerModal extends Component {
  @tracked analysis;
  @tracked plugins;
  @tracked error;
  @tracked pluginError;
  @tracked tab = "core";

  // Both reports are resolved through the page's import map, which Rails rebuilds
  // from the manifests on every render, so each names the current build.
  load = async () => {
    this.analysis = await this.#fetch("discourse/bundle-analysis").then(
      (data) => data && new Analysis(data),
      (e) => {
        this.error = e.message;
      }
    );

    // A plugin report only exists once plugins have been compiled, and its
    // absence should not take the core report down with it.
    this.plugins = await this.#fetch("discourse/bundle-analysis-plugins").catch(
      (e) => {
        this.pluginError = e.message;
      }
    );
  };

  @action
  setTab(key) {
    this.tab = key;
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
                <Report @analysis={{this.analysis}} />
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
                <PluginsReport @data={{this.plugins}} />
              {{/if}}
            </tabs.Tab>
          </DTabs>
        </div>
      </:body>
    </DModal>
  </template>
}
