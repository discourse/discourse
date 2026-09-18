import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { fmt, matches } from "./analysis";
import ExpandableRow from "./expandable-row";

// One plugin, rolled up into an expandable card. A plugin is built on its own,
// so its sizes stand apart from core's; what it shares with core is the shape of
// the question — what an entrypoint costs, and what each route adds on top.
export default class PluginCard extends ExpandableRow {
  get plugin() {
    return this.args.plugin;
  }

  get chunks() {
    return this.plugin.chunks;
  }

  get autoExpanded() {
    return !!this.args.filter;
  }

  @cached
  get entrypoints() {
    return Object.entries(this.plugin.entrypoints).map(([name, file]) => {
      const closure = this.#closure(file);
      return { name, file, files: closure.size, raw: this.#sizeOf(closure) };
    });
  }

  // Each route bundle is counted against its own entrypoint, so the number is
  // what landing on that url adds rather than what it weighs in total.
  @cached
  get routeBundles() {
    const rows = [];
    for (const [entry, bundles] of Object.entries(this.plugin.routeBundles)) {
      const base = this.#closure(this.plugin.entrypoints[entry]);
      for (const { url, fileName } of bundles) {
        const added = [...this.#closure(fileName)].filter((f) => !base.has(f));
        rows.push({
          entry,
          url,
          file: fileName,
          files: added.length,
          raw: added.reduce((n, f) => n + this.chunks[f].rawSize, 0),
        });
      }
    }
    return rows.sort((a, b) => b.raw - a.raw);
  }

  @cached
  get chunkRows() {
    return Object.values(this.chunks).sort((a, b) => b.rawSize - a.rawSize);
  }

  get rawTotal() {
    return this.#sizeOf(new Set(Object.keys(this.chunks)));
  }

  #closure(file, seen = new Set()) {
    if (!file || seen.has(file) || !this.chunks[file]) {
      return seen;
    }
    seen.add(file);
    for (const dep of this.chunks[file].imports) {
      this.#closure(dep, seen);
    }
    return seen;
  }

  #sizeOf(files) {
    let raw = 0;
    for (const f of files) {
      raw += this.chunks[f].rawSize;
    }
    return raw;
  }

  <template>
    <div class="ba-row {{if this.expanded 'open'}}">
      <button
        class="ba-head"
        style="grid-template-columns:1fr 130px 70px"
        type="button"
        {{on "click" this.toggle}}
      >
        <span class="ba-name">
          <span class="ba-tw">▶</span>
          <span class="ba-badge entry">plugin</span>
          <span class="ba-label">{{this.plugin.plugin}}</span>
        </span>
        <span class="ba-num"><b>{{fmt this.rawTotal}}</b>
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
                <span class="ba-num">{{fmt e.raw}}
                  <span class="ba-pill">raw</span></span>
                <span class="ba-num pill">{{e.files}}f</span>
              </div>
            {{/each}}
          </div>

          {{#if this.routeBundles}}
            <div class="ba-pill" style="margin:8px 0 4px">
              Route bundles — loaded on demand when a url matches.
            </div>
            <div class="ba-sub-list">
              {{#each this.routeBundles as |b|}}
                <div class="ba-plugin-line">
                  <span class="ba-name">
                    <span class="ba-badge route">{{b.entry}}</span>
                    <code class="ba-label">{{b.url}}</code>
                  </span>
                  <span class="ba-num">+{{fmt b.raw}}
                    <span class="ba-pill">added</span></span>
                  <span class="ba-num pill">+{{b.files}}f</span>
                </div>
              {{/each}}
            </div>
          {{/if}}

          <div class="ba-pill" style="margin:8px 0 4px">Chunks</div>
          <div class="ba-sub-list">
            {{#each this.chunkRows as |c|}}
              <div class="ba-plugin-line">
                <span class="ba-name">
                  {{#if c.isEntry}}
                    <span class="ba-badge entry">entry</span>
                  {{/if}}
                  <span class="ba-label" title={{c.file}}>{{c.file}}</span>
                </span>
                <span class="ba-num">{{fmt c.rawSize}}
                  <span class="ba-pill">raw</span></span>
                <span class="ba-num pill"></span>
              </div>
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
    Object.keys(plugin.chunks).some((f) => matches(f, filter)) ||
    Object.values(plugin.routeBundles)
      .flat()
      .some((b) => matches(b.url, filter))
  );
}
