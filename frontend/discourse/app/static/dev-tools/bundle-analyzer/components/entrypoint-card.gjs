import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { brotliLabel, fmt, label, routeName } from "../models/analysis.js";
import Expansion from "../models/expansion.js";
import ChunkRow from "./chunk-row.gjs";
import Row from "./row.gjs";

// One entrypoint as an expandable card of the chunks it pulls in. `@baseline`
// marks the card the others measure against, which shows its whole load rather
// than a delta. `@urls` names what loads a bundle no import site points at.
export default class EntrypointCard extends Component {
  // Every card on screen matches the filter, so a filter opens them all.
  expansion = new Expansion({
    defaultTo: () => !!this.args.filter,
    filter: () => this.args.filter ?? "",
  });

  get analysis() {
    return this.args.analysis;
  }

  get chunk() {
    return this.analysis.chunks[this.args.file];
  }

  get route() {
    return routeName(this.chunk);
  }

  // `isDynamicEntry` is set only while such a module has a chunk to itself,
  // though both kinds are fetched on demand.
  get loadedOnDemand() {
    return !this.chunk.isEntry;
  }

  get isLoaded() {
    return this.args.loaded?.has(this.args.file);
  }

  get markAdded() {
    return !this.args.baseline;
  }

  get label() {
    return label(this.chunk);
  }

  @cached
  get rootVisible() {
    return this.analysis.includes(this.args.file);
  }

  @cached
  get loadSet() {
    return this.analysis.visibleClosure(this.args.file);
  }

  @cached
  get added() {
    if (this.args.baseline) {
      return [...this.loadSet];
    }
    return [...this.loadSet].filter((f) => !this.args.baselineClosure.has(f));
  }

  @cached
  get shownTotals() {
    return this.analysis.totals(this.added);
  }

  get prefix() {
    return this.args.baseline ? "" : "+";
  }

  get shownBrotli() {
    return brotliLabel(this.shownTotals);
  }

  get sites() {
    if (this.args.urls) {
      return this.args.urls.map((url) => ({ lead: "loaded on", label: url }));
    }
    // The page names a static entrypoint itself, and a module inside one can
    // still be some file's `import()` target.
    if (this.chunk.isEntry) {
      return [];
    }
    return (this.chunk.importSites ?? []).map((importer) => ({
      lead: "imported by",
      label: importer,
    }));
  }

  @cached
  get addedSorted() {
    return this.added
      .filter((f) => f !== this.args.file)
      .filter((f) => this.analysis.chunkMatches(f, this.args.filter))
      .sort((a, b) => this.analysis.sortSize(b) - this.analysis.sortSize(a));
  }

  <template>
    <Row
      @expanded={{this.expansion.expanded}}
      @loaded={{this.isLoaded}}
      @toggle={{this.expansion.toggle}}
    >
      <:name>
        {{#if @baseline}}
          <span class="ba-badge">baseline</span>
        {{else if this.route}}
          <span class="ba-badge route">route: {{this.route}}</span>
        {{else if this.loadedOnDemand}}
          <span class="ba-badge">dynamic</span>
        {{else}}
          <span class="ba-badge">entry</span>
        {{/if}}
        <span
          class="ba-label"
          title={{if this.chunk.facadeModuleId this.chunk.facadeModuleId @file}}
        >{{this.label}}</span>
      </:name>
      <:numbers>
        <span class="ba-num"><b>{{this.prefix}}{{this.shownBrotli}}</b>
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{this.prefix}}{{fmt this.shownTotals.raw}}
          <span class="ba-pill">raw</span></span>
      </:numbers>
      <:body>
        <div class="ba-sites">
          {{#each this.sites as |site|}}
            <div class="ba-site">{{site.lead}}
              <code>{{site.label}}</code>
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
        <div class="ba-note">
          {{#if @baseline}}
            <b>{{this.loadSet.size}}</b>
            files
          {{else}}
            <b>{{this.added.length}}</b>
            new files,
            {{this.loadSet.size}}
            in its subtree
          {{/if}}
        </div>
        <div class="ba-sub-list">
          {{#if this.rootVisible}}
            <ChunkRow
              @analysis={{@analysis}}
              @file={{@file}}
              @filter={{@filter}}
              @loaded={{@loaded}}
              @root={{true}}
            />
          {{/if}}
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
      </:body>
    </Row>
  </template>
}
