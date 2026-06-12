import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fmt, routeName, stem } from "./analysis";
import ChunkRow from "./chunk-row";

// One dynamic entrypoint, showing the additional files it downloads on top of
// the initial load. Expands to its full subtree (root + added + already-loaded).
export default class DynamicCard extends Component {
  @tracked open = false;

  get analysis() {
    return this.args.analysis;
  }

  get chunk() {
    return this.analysis.chunks[this.args.file];
  }

  get route() {
    return routeName(this.chunk);
  }

  get isLoaded() {
    return this.args.loaded?.has(this.args.file);
  }

  get stemmed() {
    return stem(this.args.file);
  }

  @cached
  get loadSet() {
    return this.analysis.staticClosure(this.args.file);
  }

  get added() {
    return [...this.loadSet].filter((f) => !this.args.baselineClosure.has(f));
  }

  get addedTotals() {
    return this.analysis.totals(this.added);
  }

  get fullTotals() {
    return this.analysis.totals(this.loadSet);
  }

  get addedDisplay() {
    const t = this.addedTotals;
    return this.args.sizeKey === "brotli" ? t.brotli : t.raw;
  }

  get fullDisplay() {
    const t = this.fullTotals;
    return this.args.sizeKey === "brotli" ? t.brotli : t.raw;
  }

  get addedSorted() {
    return this.added
      .filter((f) => f !== this.args.file)
      .sort((a, b) => this.#sz(b) - this.#sz(a));
  }

  get sharedSorted() {
    return [...this.loadSet]
      .filter((f) => this.args.baselineClosure.has(f) && f !== this.args.file)
      .sort((a, b) => this.#sz(b) - this.#sz(a));
  }

  #sz(file) {
    return this.analysis.size(file, this.args.sizeKey);
  }

  @action
  toggle() {
    this.open = !this.open;
  }

  <template>
    <div class="ba-row {{if this.open 'open'}} {{if this.isLoaded 'loaded'}}">
      <button
        type="button"
        class="ba-head"
        style="grid-template-columns:1fr 130px 130px 70px"
        {{on "click" this.toggle}}
      >
        <span class="ba-name">
          <span class="ba-tw">▶</span>
          {{#if this.isLoaded}}
            <span
              class="ba-loaded-dot"
              title="Loaded in this browser session"
            >●</span>
          {{/if}}
          {{#if this.route}}
            <span class="ba-badge route">route: {{this.route}}</span>
          {{else}}
            <span class="ba-badge dyn">dynamic</span>
          {{/if}}
          <span
            class="ba-label"
            title={{if
              this.chunk.facadeModuleId
              this.chunk.facadeModuleId
              @file
            }}
          >{{this.stemmed}}</span>
        </span>
        <span class="ba-num"><b>+{{fmt this.addedDisplay}}</b>
          <span class="ba-pill">added</span></span>
        <span class="ba-num muted">{{fmt this.fullDisplay}}
          <span class="ba-pill">total</span></span>
        <span
          class="ba-num pill"
        >+{{this.added.length}}/{{this.loadSet.size}}f</span>
      </button>
      {{#if this.open}}
        <div class="ba-body">
          <div class="ba-sites">
            {{#each this.chunk.importSites as |s|}}
              <div class="ba-site">imported by
                <code>{{s.importer}}{{if s.line (concat ":" s.line)}}</code>
                {{#if s.specifier}}
                  —
                  <span class="ba-pill">import("{{s.specifier}}")</span>
                {{/if}}
              </div>
            {{else}}
              <div class="ba-site pill">no static import site found</div>
            {{/each}}
          </div>
          <div class="ba-pill" style="margin-bottom:6px">
            Adds
            <b>{{this.added.length}}</b>
            new files ({{fmt this.addedTotals.brotli}}
            br /
            {{fmt this.addedTotals.raw}}
            raw); full subtree is
            {{this.loadSet.size}}
            files.
          </div>
          <div class="ba-sub-list">
            <ChunkRow
              @file={{@file}}
              @analysis={{@analysis}}
              @filter={{@filter}}
              @root={{true}}
            />
            {{#each this.addedSorted as |f|}}
              <ChunkRow
                @file={{f}}
                @analysis={{@analysis}}
                @filter={{@filter}}
                @added={{true}}
              />
            {{/each}}
            {{#if this.sharedSorted.length}}
              <div class="ba-pill" style="margin:10px 0 4px">
                Already in initial load (free):
                {{this.sharedSorted.length}}
                files
              </div>
              {{#each this.sharedSorted as |f|}}
                <ChunkRow
                  @file={{f}}
                  @analysis={{@analysis}}
                  @filter={{@filter}}
                />
              {{/each}}
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
