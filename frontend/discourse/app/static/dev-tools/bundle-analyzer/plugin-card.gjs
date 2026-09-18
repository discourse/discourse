import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { fmt, matches } from "./analysis";
import ExpandableRow from "./expandable-row";
import PluginChunkRow from "./plugin-chunk-row";

// Brotli totals read "…" until every chunk in the set is measured, so a card
// never momentarily looks smaller than it is.
function label(totals) {
  return totals.brotliReady ? fmt(totals.brotli) : "…";
}

// One plugin, rolled up into an expandable card. A plugin is built on its own,
// so its sizes stand apart from core's; what it shares with core is the shape of
// the question — what an entrypoint costs, and what each route adds on top.
export default class PluginCard extends ExpandableRow {
  get analysis() {
    return this.args.analysis;
  }

  get plugin() {
    return this.args.plugin;
  }

  get autoExpanded() {
    return !!this.args.filter;
  }

  get totals() {
    return this.analysis.totalsFor(this.plugin);
  }

  get brotliLabel() {
    return label(this.totals);
  }

  @cached
  get entrypoints() {
    return Object.entries(this.plugin.entrypoints).map(([name, file]) => {
      const totals = this.analysis.totals(this.#closure(file));
      return { name, file, totals, label: label(totals) };
    });
  }

  // One row per bundle, listing every url that loads it. Routes are mapped url by
  // url, and a plugin usually points a whole group of them at one bundle; a row
  // each would repeat the same bytes and read like a separate download per url.
  //
  // Each bundle is counted against its own entrypoint, so the number is what
  // landing on one of its urls adds rather than what it weighs in total.
  @cached
  get routeBundles() {
    const rows = [];
    for (const [entry, bundles] of Object.entries(this.plugin.routeBundles)) {
      const base = this.#closure(this.plugin.entrypoints[entry]);
      const urlsByFile = new Map();
      for (const { url, fileName } of bundles) {
        if (!urlsByFile.has(fileName)) {
          urlsByFile.set(fileName, []);
        }
        urlsByFile.get(fileName).push(url);
      }
      for (const [file, urls] of urlsByFile) {
        const added = [...this.#closure(file)].filter((f) => !base.has(f));
        const totals = this.analysis.totals(added);
        rows.push({ entry, urls, file, totals, label: label(totals) });
      }
    }
    return rows.sort((a, b) => b.totals.raw - a.totals.raw);
  }

  get chunkRows() {
    return Object.values(this.plugin.chunks).sort(
      (a, b) => this.#sortSize(b) - this.#sortSize(a)
    );
  }

  #closure(file) {
    return this.analysis.closureOf(this.plugin, file);
  }

  #sortSize(chunk) {
    return this.analysis.brotliOf(chunk.file) ?? chunk.rawSize;
  }

  <template>
    <div class="ba-row ba-plugin-row {{if this.expanded 'open'}}">
      <button class="ba-head" type="button" {{on "click" this.toggle}}>
        <span class="ba-name">
          <span class="ba-tw">▶</span>
          <span class="ba-badge entry">plugin</span>
          <span class="ba-label">{{this.plugin.plugin}}</span>
        </span>
        <span class="ba-num"><b>{{this.brotliLabel}}</b>
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.totals.raw}}
          <span class="ba-pill">raw</span></span>
        <span class="ba-num pill">{{this.chunkRows.length}}f</span>
      </button>
      {{#if this.expanded}}
        <div class="ba-body">
          <div class="ba-sub-list">
            {{#each this.entrypoints as |e|}}
              <div class="ba-plugin-line">
                <span class="ba-name">
                  <span class="ba-badge entry">{{e.name}}</span>
                  <span class="ba-label" title={{e.file}}>{{e.file}}</span>
                </span>
                <span class="ba-num">{{e.label}}
                  <span class="ba-pill">br</span></span>
                <span class="ba-num muted">{{fmt e.totals.raw}}
                  <span class="ba-pill">raw</span></span>
                <span class="ba-num pill">{{e.totals.files}}f</span>
              </div>
            {{/each}}
          </div>

          {{#if this.routeBundles}}
            <div class="ba-pill" style="margin:8px 0 4px">
              Route bundles — loaded on demand when a url matches.
            </div>
            <div class="ba-sub-list">
              {{#each this.routeBundles as |b|}}
                <div class="ba-plugin-line --routes">
                  <span class="ba-name">
                    <span class="ba-badge route">{{b.entry}}</span>
                    <span class="ba-route-urls">
                      {{#each b.urls as |u|}}
                        <code>{{u}}</code>
                      {{/each}}
                    </span>
                  </span>
                  <span class="ba-num">+{{b.label}}
                    <span class="ba-pill">added</span></span>
                  <span class="ba-num muted">+{{fmt b.totals.raw}}
                    <span class="ba-pill">raw</span></span>
                  <span class="ba-num pill">+{{b.totals.files}}f</span>
                </div>
              {{/each}}
            </div>
          {{/if}}

          <div class="ba-pill" style="margin:8px 0 4px">Chunks</div>
          <div class="ba-sub-list">
            {{#each this.chunkRows as |c|}}
              <PluginChunkRow
                @analysis={{@analysis}}
                @chunk={{c}}
                @filter={{@filter}}
              />
            {{/each}}
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}

// True when the filter names the plugin, one of its chunks, or a route url.
export function pluginMatches(plugin, filter) {
  if (!filter) {
    return true;
  }
  return (
    matches(plugin.plugin, filter) ||
    Object.values(plugin.chunks).some(
      (c) =>
        matches(c.file, filter) || c.modules.some((m) => matches(m.id, filter))
    ) ||
    Object.values(plugin.routeBundles)
      .flat()
      .some((b) => matches(b.url, filter))
  );
}
