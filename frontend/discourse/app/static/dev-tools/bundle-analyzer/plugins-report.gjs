import { cached } from "@glimmer/tracking";
import { brotliLabel, fmt } from "./analysis";
import AnalyzerToolbar from "./analyzer-toolbar";
import FilterableReport from "./filterable-report";
import PluginCard, { pluginMatches } from "./plugin-card";

export default class PluginsReport extends FilterableReport {
  get totals() {
    return this.analysis.totals(Object.keys(this.analysis.chunks));
  }

  @cached
  get visible() {
    const shown = this.analysis.plugins.filter(
      (p) => this.#hasContent(p) && pluginMatches(p, this.filter)
    );
    const sizes = new Map(
      shown.map((p) => [p, this.analysis.totalsFor(p).raw])
    );
    return shown.sort((a, b) => sizes.get(b) - sizes.get(a));
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

      <AnalyzerToolbar
        @filter={{this.filter}}
        @onFilter={{this.updateFilter}}
        @placeholder="Filter plugins / chunks / modules / routes…"
        @view={{@view}}
      />

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
