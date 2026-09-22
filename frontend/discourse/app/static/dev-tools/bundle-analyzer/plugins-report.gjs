import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { brotliLabel, fmt } from "./analysis";
import LoadedChunks from "./loaded-chunks";
import PluginCard, { pluginMatches } from "./plugin-card";

export default class PluginsReport extends Component {
  @tracked filter = "";

  loaded = new LoadedChunks(this.args.analysis.chunks);

  constructor() {
    super(...arguments);
    this.args.analysis.loaded = this.loaded;
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.loaded.teardown();
  }

  get analysis() {
    return this.args.analysis;
  }

  get totals() {
    return this.analysis.totals(Object.keys(this.analysis.chunks));
  }

  @cached
  get visible() {
    return this.analysis.plugins
      .filter((p) => this.#hasContent(p) && pluginMatches(p, this.filter))
      .sort(
        (a, b) =>
          this.analysis.totalsFor(b).raw - this.analysis.totalsFor(a).raw
      );
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
  }

  // A plugin with nothing left to show is dropped rather than listed at zero.
  #hasContent(plugin) {
    return Object.keys(plugin.chunks).some((f) => this.analysis.includes(f));
  }

  <template>
    <div class="bundle-analyzer">
      <div class="ba-header">
        <span class="ba-sub">
          {{this.analysis.plugins.length}}
          plugins ·
          {{this.analysis.chunkCount}}
          chunks ·
          {{brotliLabel this.totals}}
          br /
          {{fmt this.totals.raw}}
          raw · generated
          {{this.analysis.data.generatedAt}}
        </span>
      </div>

      <div class="ba-toolbar">
        <input
          placeholder="Filter plugins / chunks / modules / routes…"
          type="search"
          {{on "input" this.updateFilter}}
        />
        <DToggleSwitch
          @label="dev_tools.bundle_analyzer.only_loaded"
          @state={{@view.onlyLoaded}}
          {{on "click" @toggleOnlyLoaded}}
        />
      </div>

      <section>
        <div class="ba-hint">
          Each plugin is built on its own, so these sizes are separate from
          core's and from each other. A route bundle counts only what it adds on
          top of the entrypoint that loads it.
        </div>
        <div>
          {{#each this.visible as |p|}}
            <PluginCard
              @analysis={{this.analysis}}
              @filter={{this.filter}}
              @loaded={{this.loaded}}
              @plugin={{p}}
            />
          {{else}}
            <div class="ba-empty">No matches.</div>
          {{/each}}
        </div>
      </section>
    </div>
  </template>
}
