import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { fmt, matches } from "./analysis";
import EntrypointCard from "./entrypoint-card";
import LoadedChunks from "./loaded-chunks";

export default class Report extends Component {
  @tracked sizeKey = "brotli";
  @tracked filter = "";

  loaded = new LoadedChunks(this.args.analysis.chunks);

  willDestroy() {
    super.willDestroy(...arguments);
    this.loaded.teardown();
  }

  get analysis() {
    return this.args.analysis;
  }

  get sizeIsBrotli() {
    return this.sizeKey === "brotli";
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

  #sz(file) {
    return this.analysis.size(file, this.sizeKey);
  }

  #addedSize(file) {
    const base = this.baselineClosure;
    return [...this.analysis.staticClosure(file)]
      .filter((x) => !base.has(x))
      .reduce((n, x) => n + this.#sz(x), 0);
  }

  #cardMatches(file) {
    return (
      matches(file, this.filter) ||
      matches(this.analysis.chunks[file].name, this.filter)
    );
  }

  @action
  setSize(key) {
    this.sizeKey = key;
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
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
          {{fmt this.loadedTotals.brotli}}
          br
        </span>
      </div>

      <div class="ba-toolbar">
        <div class="ba-seg">
          <button
            type="button"
            class={{if this.sizeIsBrotli "on"}}
            {{on "click" (fn this.setSize "brotli")}}
          >brotli</button>
          <button
            type="button"
            class={{unless this.sizeIsBrotli "on"}}
            {{on "click" (fn this.setSize "raw")}}
          >raw</button>
        </div>
        <input
          type="search"
          placeholder="Filter files / modules…"
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
              @file={{f}}
              @analysis={{this.analysis}}
              @filter={{this.filter}}
              @sizeKey={{this.sizeKey}}
              @baselineClosure={{this.baselineClosure}}
              @baseline={{eq f this.baselineFile}}
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
              @file={{f}}
              @analysis={{this.analysis}}
              @filter={{this.filter}}
              @sizeKey={{this.sizeKey}}
              @baselineClosure={{this.baselineClosure}}
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
