import { cached } from "@glimmer/tracking";
import { eq } from "discourse/truth-helpers";
import { brotliLabel } from "./analysis";
import AnalyzerToolbar from "./analyzer-toolbar";
import EntrypointCard from "./entrypoint-card";
import FilterableReport from "./filterable-report";

export default class Report extends FilterableReport {
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

  @cached
  get staticVisible() {
    const base = this.baselineFile;
    const others = this.#bySizeDescending(
      this.analysis.entrypoints.filter((f) => f !== base)
    );
    return [base, ...others].filter((f) => this.#visible(f));
  }

  @cached
  get dynamicVisible() {
    return this.#bySizeDescending(
      this.analysis.dynamicEntrypoints.filter((f) => this.#visible(f))
    );
  }

  @cached
  get loadedTotals() {
    return this.analysis.totals(
      [...this.loaded.files].filter((f) => this.analysis.chunks[f])
    );
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
          {{this.analysis.data.emberEnv}}
          ·
          {{this.analysis.chunkCount}}
          chunks ·
        </span>
        <span class="ba-sub">
          <span class="ba-loaded-dot">●</span>
          loaded in this browser:
          {{this.loadedTotals.files}}
          chunks ·
          {{brotliLabel this.loadedTotals}}
          br
        </span>
      </div>

      <AnalyzerToolbar
        @filter={{this.filter}}
        @onFilter={{this.updateFilter}}
        @placeholder="Filter files / modules…"
        @view={{@view}}
      />

      <section>
        <h2>Static entrypoints</h2>
        <div class="ba-hint">
          Entry chunks the build produces — script tags and workers.
          <code>discourse</code>
          is the baseline; every other card counts only the bytes it adds on top
          of it.
        </div>
        <div>
          {{#each this.staticVisible as |f|}}
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
      </section>

      <section>
        <h2>Dynamic entrypoints</h2>
        <div class="ba-hint">
          Each is loaded on demand via
          <code>import()</code>. “Additional” counts only chunks not already in
          the
          <code>discourse</code>
          baseline above.
        </div>
        <div>
          {{#each this.dynamicVisible as |f|}}
            <EntrypointCard
              @analysis={{this.analysis}}
              @baselineClosure={{this.baselineClosure}}
              @file={{f}}
              @filter={{this.filter}}
              @loaded={{this.loaded}}
            />
          {{else}}
            <div class="ba-empty">No dynamic entrypoints.</div>
          {{/each}}
        </div>
      </section>
    </div>
  </template>
}
