import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fmt, matches } from "./analysis";
import ChunkRow from "./chunk-row";
import DynamicCard from "./dynamic-card";
import LoadedChunks from "./loaded-chunks";

export default class Report extends Component {
  @tracked sizeKey = "brotli";
  @tracked filter = "";
  @tracked baseline;

  loaded = new LoadedChunks(this.args.analysis.chunks);

  isBaseline = (file) => this.baseline.has(file);

  constructor() {
    super(...arguments);
    const { entrypoints, chunks } = this.args.analysis;
    let base = entrypoints.filter((f) =>
      ["discourse", "vendor"].includes(chunks[f].name)
    );
    if (base.length === 0) {
      base = [...entrypoints];
    }
    this.baseline = new Set(base);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.loaded.teardown();
  }

  get analysis() {
    return this.args.analysis;
  }

  get loadedTotals() {
    const files = [...this.loaded.files].filter((f) => this.analysis.chunks[f]);
    return { count: files.length, ...this.analysis.totals(new Set(files)) };
  }

  get entrypointRows() {
    return this.analysis.entrypoints.map((file) => ({
      file,
      name: this.analysis.chunks[file].name,
      brotliSize: this.analysis.chunks[file].brotliSize,
    }));
  }

  get sizeIsBrotli() {
    return this.sizeKey === "brotli";
  }

  @cached
  get baselineClosure() {
    return this.analysis.closureOf([...this.baseline]);
  }

  @cached
  get initialFiles() {
    return [...this.baselineClosure].sort((a, b) => this.#sz(b) - this.#sz(a));
  }

  get initialVisible() {
    return this.initialFiles.filter(
      (f) =>
        matches(f, this.filter) ||
        matches(this.analysis.chunks[f].name, this.filter) ||
        this.analysis.chunks[f].modules.some((m) => matches(m.id, this.filter))
    );
  }

  get initialTotals() {
    const t = this.analysis.totals(new Set(this.initialFiles));
    const modules = this.initialFiles.reduce(
      (n, f) => n + this.analysis.chunks[f].moduleCount,
      0
    );
    return { ...t, modules };
  }

  get dynamicVisible() {
    const base = this.baselineClosure;
    return this.analysis.dynamicEntrypoints
      .filter(
        (f) =>
          matches(f, this.filter) ||
          matches(this.analysis.chunks[f].name, this.filter)
      )
      .sort((a, b) => this.#addedSize(b, base) - this.#addedSize(a, base));
  }

  #sz(file) {
    return this.analysis.size(file, this.sizeKey);
  }

  #addedSize(file, base) {
    return [...this.analysis.staticClosure(file)]
      .filter((x) => !base.has(x))
      .reduce((n, x) => n + this.#sz(x), 0);
  }

  @action
  toggleBaseline(file) {
    const next = new Set(this.baseline);
    if (next.has(file)) {
      next.delete(file);
    } else {
      next.add(file);
    }
    this.baseline = next;
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

      <section>
        <h2>Initial page load</h2>
        <div class="ba-hint">
          Files and bytes downloaded before any dynamic import. Toggle which
          entrypoints count as the baseline.
        </div>

        <div class="ba-baseline">
          {{#each this.entrypointRows as |ep|}}
            <label class={{if (this.isBaseline ep.file) "on"}}>
              <input
                type="checkbox"
                checked={{this.isBaseline ep.file}}
                {{on "change" (fn this.toggleBaseline ep.file)}}
              />
              {{ep.name}}
              <span class="ba-pill">{{fmt ep.brotliSize}}</span>
            </label>
          {{/each}}
        </div>

        <div class="ba-cards">
          <div class="ba-card"><div class="k">Files</div><div
              class="v"
            >{{this.initialTotals.files}}</div></div>
          <div class="ba-card"><div class="k">Download (brotli)</div><div
              class="v"
            >{{fmt this.initialTotals.brotli}}</div></div>
          <div class="ba-card"><div class="k">Uncompressed</div><div
              class="v"
            >{{fmt this.initialTotals.raw}}</div></div>
          <div class="ba-card"><div class="k">Modules</div><div
              class="v"
            >{{this.initialTotals.modules}}</div></div>
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

        <div>
          {{#each this.initialVisible as |f|}}
            <ChunkRow
              @file={{f}}
              @analysis={{this.analysis}}
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
          the initial load above.
        </div>
        <div>
          {{#each this.dynamicVisible as |f|}}
            <DynamicCard
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
