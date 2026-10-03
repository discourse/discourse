import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { brotliLabel } from "./analysis";
import AnalyzerToolbar from "./analyzer-toolbar";
import EntrypointCard from "./entrypoint-card";
import PluginCard, { pluginMatches } from "./plugin-card";

const EMPTY = { files: 0, raw: 0, brotli: 0, brotliReady: true };

function sum(totals) {
  return totals.reduce(
    (a, b) => ({
      files: a.files + b.files,
      raw: a.raw + b.raw,
      brotli: a.brotli + b.brotli,
      brotliReady: a.brotliReady && b.brotliReady,
    }),
    EMPTY
  );
}

// Core and the plugins in one list. They are separate builds and their sizes do
// not add up into a single figure for the page, but they answer the same
// question, and a reader comparing them should not have to hold one in their
// head while looking at the other.
export default class Report extends Component {
  @tracked filter = "";
  @tracked scope = "all";

  get core() {
    return this.scope === "plugins" ? null : this.args.core;
  }

  get plugins() {
    return this.scope === "core" ? null : this.args.plugins;
  }

  get shownTotals() {
    return sum(
      [this.core?.loadedTotals, this.plugins?.loadedTotals].filter(Boolean)
    );
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

  // The badge on a card says how it loads, so one list rather than a section
  // per kind, ordered by what each adds over the baseline.
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
      (p) => this.#hasContent(p) && pluginMatches(p, this.filter)
    );
    const sizes = new Map(shown.map((p) => [p, this.plugins.totalsFor(p).raw]));
    return shown.sort((a, b) => sizes.get(b) - sizes.get(a));
  }

  get empty() {
    return !this.visibleEntrypoints.length && !this.visiblePlugins.length;
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
  }

  @action
  setScope(scope) {
    this.scope = scope;
  }

  // Sized once per file, not once per comparison: each call walks the file's
  // whole import closure.
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
        @filter={{this.filter}}
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
