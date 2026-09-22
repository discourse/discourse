import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import { brotliLabel, fmt, matches } from "./analysis";
import EntrypointCard from "./entrypoint-card";
import ExpandableRow from "./expandable-row";
import { routeBundlesByFile } from "./plugins-analysis";

// One plugin, expanding to the same cards the core tab is built from: what it
// loads up front, and what its routes load on demand.
//
// `main` is the baseline — a plugin loads it on every page, so an admin or test
// entrypoint reads as what it adds on top. A route bundle measures against the
// entrypoint that owns it instead, since reaching one of its urls means that
// entrypoint is already loaded.
export default class PluginCard extends ExpandableRow {
  get analysis() {
    return this.args.analysis;
  }

  get plugin() {
    return this.args.plugin;
  }

  get graph() {
    return this.analysis.graphFor(this.plugin);
  }

  get autoExpanded() {
    return !!this.args.filter;
  }

  get totals() {
    return this.analysis.totalsFor(this.plugin);
  }

  get baselineFile() {
    const { entrypoints } = this.plugin;
    return entrypoints.main ?? Object.values(entrypoints)[0];
  }

  @cached
  get baselineClosure() {
    return this.graph.staticClosure(this.baselineFile);
  }

  get entrypoints() {
    const base = this.baselineFile;
    const others = Object.values(this.plugin.entrypoints).filter(
      (f) => f !== base
    );
    return [base, ...others].filter(Boolean);
  }

  @cached
  get routeBundles() {
    return [...routeBundlesByFile(this.plugin)]
      .map(([file, { entry, urls }]) => ({
        file,
        urls,
        base: this.graph.staticClosure(this.plugin.entrypoints[entry]),
      }))
      .sort(
        (a, b) => this.graph.sortSize(b.file) - this.graph.sortSize(a.file)
      );
  }

  <template>
    <div class="ba-row {{if this.expanded 'open'}}">
      <button class="ba-head" type="button" {{on "click" this.toggle}}>
        <span class="ba-name">
          <span class="ba-tw">▶</span>
          <span class="ba-badge entry">plugin</span>
          <span class="ba-label">{{this.plugin.plugin}}</span>
        </span>
        <span class="ba-num"><b>{{brotliLabel this.totals}}</b>
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.totals.raw}}
          <span class="ba-pill">raw</span></span>
      </button>
      {{#if this.expanded}}
        <div class="ba-body">
          <div class="ba-hint">Loaded up front when the plugin is active.</div>
          <div class="ba-sub-list">
            {{#each this.entrypoints as |f|}}
              <EntrypointCard
                @analysis={{this.graph}}
                @baseline={{eq f this.baselineFile}}
                @baselineClosure={{this.baselineClosure}}
                @file={{f}}
                @filter={{@filter}}
                @loaded={{@loaded}}
              />
            {{/each}}
          </div>

          {{#if this.routeBundles}}
            <div class="ba-hint" style="margin-top:10px">
              Loaded on demand when a url matches. Each counts only what it adds
              on top of the entrypoint that loads it.
            </div>
            <div class="ba-sub-list">
              {{#each this.routeBundles as |b|}}
                <EntrypointCard
                  @analysis={{this.graph}}
                  @baselineClosure={{b.base}}
                  @file={{b.file}}
                  @filter={{@filter}}
                  @loaded={{@loaded}}
                  @urls={{b.urls}}
                />
              {{/each}}
            </div>
          {{/if}}
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
