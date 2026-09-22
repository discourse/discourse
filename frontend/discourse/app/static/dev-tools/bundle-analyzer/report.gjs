import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { brotliLabel } from "./analysis";
import EntrypointCard from "./entrypoint-card";
import LoadedChunks from "./loaded-chunks";

export default class Report extends Component {
  @tracked filter = "";

  loaded = new LoadedChunks(this.args.analysis.chunks);

  willDestroy() {
    super.willDestroy(...arguments);
    this.loaded.teardown();
  }

  get analysis() {
    return this.args.analysis;
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

  get staticVisible() {
    const base = this.baselineFile;
    const others = this.analysis.entrypoints
      .filter((f) => f !== base)
      .sort((a, b) => this.#addedSize(b) - this.#addedSize(a));
    return [base, ...others].filter((f) => this.#cardMatches(f));
  }

  get dynamicVisible() {
    return this.analysis.dynamicEntrypoints
      .filter((f) => this.#cardMatches(f))
      .sort((a, b) => this.#addedSize(b) - this.#addedSize(a));
  }

  get loadedTotals() {
    const files = [...this.loaded.files].filter((f) => this.analysis.chunks[f]);
    return { count: files.length, ...this.analysis.totals(new Set(files)) };
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
  }

  #addedSize(file) {
    const base = this.baselineClosure;
    return [...this.analysis.staticClosure(file)]
      .filter((x) => !base.has(x))
      .reduce((n, x) => n + this.analysis.sortSize(x), 0);
  }

  #cardMatches(file) {
    if (!this.filter) {
      return true;
    }
    // Match if any chunk this entrypoint introduces (its subtree, minus the
    // shared baseline) matches by path / name / bundled module path. The
    // baseline card owns everything in its own subtree.
    const base = this.baselineClosure;
    const isBaseline = file === this.baselineFile;
    for (const f of this.analysis.staticClosure(file)) {
      if (!isBaseline && f !== file && base.has(f)) {
        continue;
      }
      if (this.analysis.chunkMatches(f, this.filter)) {
        return true;
      }
    }
    return false;
  }

  <template>
    <div class="bundle-analyzer">
      <div class="ba-header">
        <span class="ba-sub">
          {{this.analysis.data.emberEnv}}
          ·
          {{this.analysis.chunkCount}}
          chunks · generated
          {{this.analysis.data.generatedAt}}
        </span>
        <span class="ba-sub">
          <span class="ba-loaded-dot">●</span>
          loaded in this browser:
          {{this.loadedTotals.count}}
          chunks ·
          {{brotliLabel this.loadedTotals}}
          br
        </span>
      </div>

      <div class="ba-toolbar">
        <input
          placeholder="Filter files / modules…"
          type="search"
          {{on "input" this.updateFilter}}
        />
      </div>

      <section>
        <h2>Static entrypoints</h2>
        <div class="ba-hint">
          Loaded up front via
          <code>&lt;script&gt;</code>
          tags.
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
