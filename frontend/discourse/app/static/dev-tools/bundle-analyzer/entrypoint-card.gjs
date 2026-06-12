import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fmt, routeName, stem } from "./analysis";
import ChunkRow from "./chunk-row";

// One entrypoint (static or dynamic), rolled up into an expandable card that
// shows the chunks it pulls in. `@baseline` marks discourse.js, the basis every
// other card measures its "additional" bytes against; that card shows its full
// initial load instead of a delta.
export default class EntrypointCard extends Component {
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

  get isDynamic() {
    return this.chunk.isDynamicEntry;
  }

  get isLoaded() {
    return this.args.loaded?.has(this.args.file);
  }

  get markAdded() {
    return !this.args.baseline;
  }

  get stemmed() {
    return stem(this.args.file);
  }

  @cached
  get loadSet() {
    return this.analysis.staticClosure(this.args.file);
  }

  // For the baseline everything counts as the initial load; for everyone else,
  // only the chunks not already in the baseline.
  get added() {
    if (this.args.baseline) {
      return [...this.loadSet];
    }
    return [...this.loadSet].filter((f) => !this.args.baselineClosure.has(f));
  }

  get addedTotals() {
    return this.analysis.totals(this.added);
  }

  get fullTotals() {
    return this.analysis.totals(this.loadSet);
  }

  // Brotli total is "…" until every chunk in the set is measured, so a parent
  // never momentarily looks smaller than it really is.
  get addedBrotliLabel() {
    const t = this.addedTotals;
    return t.brotliReady ? fmt(t.brotli) : "…";
  }

  get fullBrotliLabel() {
    const t = this.fullTotals;
    return t.brotliReady ? fmt(t.brotli) : "…";
  }

  get addedSorted() {
    return this.added
      .filter((f) => f !== this.args.file)
      .sort((a, b) => this.analysis.sortSize(b) - this.analysis.sortSize(a));
  }

  get sharedSorted() {
    if (this.args.baseline) {
      return [];
    }
    return [...this.loadSet]
      .filter((f) => this.args.baselineClosure.has(f) && f !== this.args.file)
      .sort((a, b) => this.analysis.sortSize(b) - this.analysis.sortSize(a));
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
          {{#if @baseline}}
            <span class="ba-badge base">baseline</span>
          {{else if this.route}}
            <span class="ba-badge route">route: {{this.route}}</span>
          {{else if this.isDynamic}}
            <span class="ba-badge dyn">dynamic</span>
          {{else}}
            <span class="ba-badge entry">entry</span>
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
        {{#if @baseline}}
          <span class="ba-num"><b>{{this.fullBrotliLabel}}</b>
            <span class="ba-pill">initial</span></span>
          <span class="ba-num muted">{{fmt this.fullTotals.raw}}
            <span class="ba-pill">raw</span></span>
          <span class="ba-num pill">{{this.loadSet.size}}f</span>
        {{else}}
          <span class="ba-num"><b>+{{this.addedBrotliLabel}}</b>
            <span class="ba-pill">added</span></span>
          <span class="ba-num muted">+{{fmt this.addedTotals.raw}}
            <span class="ba-pill">raw</span></span>
          <span
            class="ba-num pill"
          >+{{this.added.length}}/{{this.loadSet.size}}f</span>
        {{/if}}
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
              <div class="ba-site pill">
                {{#if this.isDynamic}}
                  no static import site found
                {{else}}
                  loaded as a top-level entrypoint
                {{/if}}
              </div>
            {{/each}}
          </div>
          {{#if @baseline}}
            <div class="ba-pill" style="margin-bottom:6px">
              Initial load:
              <b>{{this.loadSet.size}}</b>
              files ({{this.fullBrotliLabel}}
              br /
              {{fmt this.fullTotals.raw}}
              raw).
            </div>
          {{else}}
            <div class="ba-pill" style="margin-bottom:6px">
              Adds
              <b>{{this.added.length}}</b>
              new files ({{this.addedBrotliLabel}}
              br /
              {{fmt this.addedTotals.raw}}
              raw); full subtree is
              {{this.loadSet.size}}
              files.
            </div>
          {{/if}}
          <div class="ba-sub-list">
            <ChunkRow
              @file={{@file}}
              @analysis={{@analysis}}
              @filter={{@filter}}
              @loaded={{@loaded}}
              @root={{true}}
            />
            {{#each this.addedSorted as |f|}}
              <ChunkRow
                @file={{f}}
                @analysis={{@analysis}}
                @filter={{@filter}}
                @loaded={{@loaded}}
                @added={{this.markAdded}}
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
                  @loaded={{@loaded}}
                />
              {{/each}}
            {{/if}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
