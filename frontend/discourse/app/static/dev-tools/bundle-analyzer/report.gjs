import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { brotliLabel } from "./analysis";
import AnalyzerToolbar from "./analyzer-toolbar";
import EntrypointCard from "./entrypoint-card";

export default class Report extends Component {
  @tracked filter = "";

  get analysis() {
    return this.args.analysis;
  }

  get loaded() {
    return this.analysis.loaded;
  }

  // discourse.js is the baseline every other entrypoint measures against.
  get baselineFile() {
    const { entrypoints, chunks } = this.analysis;
    return (
      entrypoints.find((f) => chunks[f].name === "discourse") ?? entrypoints[0]
    );
  }

  @cached
  get baselineClosure() {
    return this.analysis.staticClosure(this.baselineFile);
  }

  // One list: the badge on a card already says how it loads, and splitting on
  // that buried the biggest dynamic entries below every static one.
  @cached
  get visible() {
    const base = this.baselineFile;
    const others = this.#bySizeDescending(
      [...this.analysis.entrypoints, ...this.analysis.dynamicEntrypoints]
        .filter((f) => f !== base)
        .filter((f) => this.#visible(f))
    );
    return (this.#visible(base) ? [base] : []).concat(others);
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
  }

  // Sized once per file, not once per comparison: each call walks the file's
  // whole import closure.
  #bySizeDescending(files) {
    const sizes = new Map(files.map((f) => [f, this.#addedSize(f)]));
    return files.sort((a, b) => sizes.get(b) - sizes.get(a));
  }

  #addedSize(file) {
    const base = this.baselineClosure;
    return [...this.analysis.visibleClosure(file)]
      .filter((x) => !base.has(x))
      .reduce((n, x) => n + this.analysis.sortSize(x), 0);
  }

  #visible(file) {
    const base = file === this.baselineFile ? null : this.baselineClosure;
    return this.analysis.cardVisible(file, this.filter, base);
  }

  <template>
    <div class="bundle-analyzer">
      <div class="ba-header">
        <span class="ba-sub">
          {{this.analysis.chunkCount}}
          chunks ·
          <span class="ba-loaded-dot">●</span>
          {{this.analysis.loadedTotals.files}}
          loaded,
          {{brotliLabel this.analysis.loadedTotals}}
          br
        </span>
      </div>

      <AnalyzerToolbar
        @filter={{this.filter}}
        @onFilter={{this.updateFilter}}
        @placeholder="Filter chunks or modules…"
        @view={{@view}}
      />

      <div>
        {{#each this.visible as |f|}}
          <EntrypointCard
            @analysis={{this.analysis}}
            @baseline={{eq f this.baselineFile}}
            @baselineClosure={{this.baselineClosure}}
            @file={{f}}
            @filter={{this.filter}}
            @loaded={{this.loaded}}
          />
        {{else}}
          <div class="ba-empty">No matches.</div>
        {{/each}}
      </div>
    </div>
  </template>
}
