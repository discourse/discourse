import { cached } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { brotliLabel, fmt, routeName, stem } from "./analysis";
import ChunkRow from "./chunk-row";
import ExpandableRow from "./expandable-row";

// One entrypoint (static or dynamic), rolled up into an expandable card that
// shows the chunks it pulls in. `@baseline` marks discourse.js, the basis every
// other card measures its "additional" bytes against; that card shows its full
// initial load instead of a delta.
export default class EntrypointCard extends ExpandableRow {
  get analysis() {
    return this.args.analysis;
  }

  get chunk() {
    return this.analysis.chunks[this.args.file];
  }

  get route() {
    return routeName(this.chunk);
  }

  // Not `isDynamicEntry`: rolldown sets that only when a dynamically-imported
  // module gets a chunk to itself, and clears it once several of them share
  // one. Both are fetched on demand, so ask what the chunk is instead.
  get loadedOnDemand() {
    return !this.chunk.isEntry;
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

  get addedBrotliLabel() {
    return brotliLabel(this.addedTotals);
  }

  get fullBrotliLabel() {
    return brotliLabel(this.fullTotals);
  }

  // Every card on screen matches the active filter, so a filter opens them all.
  get autoExpanded() {
    return !!this.args.filter;
  }

  get addedSorted() {
    return this.added
      .filter((f) => f !== this.args.file)
      .filter((f) => this.analysis.chunkMatches(f, this.args.filter))
      .sort((a, b) => this.analysis.sortSize(b) - this.analysis.sortSize(a));
  }

  <template>
    <div
      class="ba-row {{if this.expanded 'open'}} {{if this.isLoaded 'loaded'}}"
    >
      <button class="ba-head" type="button" {{on "click" this.toggle}}>
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
          {{else if this.loadedOnDemand}}
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
        {{else}}
          <span class="ba-num"><b>+{{this.addedBrotliLabel}}</b>
            <span class="ba-pill">added</span></span>
          <span class="ba-num muted">+{{fmt this.addedTotals.raw}}
            <span class="ba-pill">raw</span></span>
        {{/if}}
      </button>
      {{#if this.expanded}}
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
                {{#if this.loadedOnDemand}}
                  no import site found
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
              @analysis={{@analysis}}
              @file={{@file}}
              @filter={{@filter}}
              @loaded={{@loaded}}
              @root={{true}}
            />
            {{#each this.addedSorted as |f|}}
              <ChunkRow
                @added={{this.markAdded}}
                @analysis={{@analysis}}
                @file={{f}}
                @filter={{@filter}}
                @loaded={{@loaded}}
              />
            {{/each}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
