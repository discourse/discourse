import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { brotliLabel } from "../models/analysis.js";
import AnalyzerToolbar from "./analyzer-toolbar.gjs";
import EntrypointCard from "./entrypoint-card.gjs";
import PluginCard, { pluginMatches } from "./plugin-card.gjs";

const EMPTY = { files: 0, raw: 0, brotli: 0, brotliReady: true };

function sum(a, b) {
  return {
    files: a.files + b.files,
    raw: a.raw + b.raw,
    brotli: a.brotli + b.brotli,
    brotliReady: a.brotliReady && b.brotliReady,
  };
}

// Core and the plugins in one list, though their sizes do not add up into a
// single figure: they are separate builds.
export default class Report extends Component {
  @tracked query = "";
  @tracked scope = "all";

  // The input shows what was typed; matching reads the normalised form.
  get filter() {
    return this.query.trim().toLowerCase();
  }

  get core() {
    return this.scope === "plugins" ? null : this.args.core;
  }

  get plugins() {
    return this.scope === "core" ? null : this.args.plugins;
  }

  get shownTotals() {
    return [this.core?.loadedTotals, this.plugins?.loadedTotals]
      .filter(Boolean)
      .reduce(sum, EMPTY);
  }

  get chunkCount() {
    return (this.core?.chunkCount ?? 0) + (this.plugins?.chunkCount ?? 0);
  }

  // discourse.js is the baseline every other entrypoint measures against.
  get baselineFile() {
    const { entrypoints, chunks } = this.args.core;
    return (
      entrypoints.find((f) => chunks[f].name === "discourse") ?? entrypoints[0]
    );
  }

  @cached
  get baselineClosure() {
    return this.args.core.staticClosure(this.baselineFile);
  }

  // Ordered by what each adds over the baseline; the badge says how it loads.
  @cached
  get visibleEntrypoints() {
    if (!this.core) {
      return [];
    }
    const base = this.baselineFile;
    const others = this.#bySizeDescending(
      [...this.core.entrypoints, ...this.core.dynamicEntrypoints]
        .filter((f) => f !== base)
        .filter((f) => this.#visible(f))
    );
    return (this.#visible(base) ? [base] : []).concat(others);
  }

  @cached
  get visiblePlugins() {
    if (!this.plugins) {
      return [];
    }
    const shown = this.plugins.plugins.filter(
      (p) =>
        this.#hasContent(p) &&
        pluginMatches(this.plugins.graphFor(p), p, this.filter)
    );
    const sizes = new Map(shown.map((p) => [p, this.plugins.totalsFor(p).raw]));
    return shown.sort((a, b) => sizes.get(b) - sizes.get(a));
  }

  get empty() {
    return !this.visibleEntrypoints.length && !this.visiblePlugins.length;
  }

  @action
  updateFilter(event) {
    this.query = event.target.value;
  }

  @action
  setScope(scope) {
    this.scope = scope;
  }

  // Sized once per file, not once per comparison.
  #bySizeDescending(files) {
    const sizes = new Map(files.map((f) => [f, this.#addedSize(f)]));
    return files.sort((a, b) => sizes.get(b) - sizes.get(a));
  }

  #addedSize(file) {
    const base = this.baselineClosure;
    return [...this.core.visibleClosure(file)]
      .filter((x) => !base.has(x))
      .reduce((n, x) => n + this.core.sortSize(x), 0);
  }

  #visible(file) {
    const base = file === this.baselineFile ? null : this.baselineClosure;
    return this.core.cardVisible(file, this.filter, base);
  }

  #hasContent(plugin) {
    return Object.keys(plugin.chunks).some((f) => this.plugins.includes(f));
  }

  <template>
    <div class="bundle-analyzer">
      <div class="ba-header">
        <span class="ba-sub">
          {{this.chunkCount}}
          chunks ·
          <span class="ba-loaded-dot">●</span>
          {{this.shownTotals.files}}
          loaded,
          {{brotliLabel this.shownTotals}}
          br
        </span>
      </div>

      <AnalyzerToolbar
        @filter={{this.query}}
        @onFilter={{this.updateFilter}}
        @onScope={{this.setScope}}
        @placeholder="Filter chunks, modules or plugins…"
        @scope={{this.scope}}
        @view={{@view}}
      />

      <div>
        {{#each this.visibleEntrypoints as |f|}}
          <EntrypointCard
            @analysis={{this.core}}
            @baseline={{eq f this.baselineFile}}
            @baselineClosure={{this.baselineClosure}}
            @file={{f}}
            @filter={{this.filter}}
            @loaded={{this.core.loaded}}
          />
        {{/each}}
        {{#each this.visiblePlugins as |p|}}
          <PluginCard
            @analysis={{this.plugins}}
            @filter={{this.filter}}
            @loaded={{this.plugins.loaded}}
            @plugin={{p}}
          />
        {{/each}}
        {{#if this.empty}}
          <div class="ba-empty">No matches.</div>
        {{/if}}
      </div>
    </div>
  </template>
}
