import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { brotliLabel, fmt, matches } from "../models/analysis.js";
import Expansion from "../models/expansion.js";
import { routeBundlesByFile } from "../models/plugins-analysis.js";
import EntrypointCard from "./entrypoint-card.gjs";
import Row from "./row.gjs";

// One plugin, expanding to the cards the core tab is built from. `main` is the
// baseline, since a plugin loads it on every page; a route bundle measures
// against the entrypoint that owns it, which its urls have already loaded.
export default class PluginCard extends Component {
  expansion = new Expansion({
    defaultTo: () => !!this.args.filter,
    filter: () => this.args.filter ?? "",
  });

  get analysis() {
    return this.args.analysis;
  }

  get plugin() {
    return this.args.plugin;
  }

  get graph() {
    return this.analysis.graphFor(this.plugin);
  }

  // Any one chunk is enough, so a collapsed list says which plugins this page
  // pulled in.
  get isLoaded() {
    return Object.keys(this.plugin.chunks).some((f) =>
      this.args.loaded?.has(f)
    );
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

  @cached
  get entrypoints() {
    const base = this.baselineFile;
    const others = Object.values(this.plugin.entrypoints).filter(
      (f) => f !== base
    );
    return [base, ...others].filter(
      (f) =>
        f &&
        this.graph.cardVisible(
          f,
          this.args.filter,
          f === base ? null : this.baselineClosure
        )
    );
  }

  @cached
  get routeBundles() {
    return [...routeBundlesByFile(this.plugin)]
      .map(([file, { entry, urls }]) => ({
        file,
        urls,
        base: this.graph.staticClosure(this.plugin.entrypoints[entry]),
      }))
      .filter(
        (b) =>
          this.graph.cardVisible(b.file, this.args.filter, b.base) ||
          // A filter naming one of its urls keeps a bundle whose chunks do not
          // match; with nothing typed, what it adds is the only question.
          (!!this.args.filter &&
            this.graph.visibleClosure(b.file).size > 0 &&
            b.urls.some((u) => matches(u, this.args.filter)))
      )
      .sort(
        (a, b) => this.graph.sortSize(b.file) - this.graph.sortSize(a.file)
      );
  }

  <template>
    <Row
      @expanded={{this.expansion.expanded}}
      @loaded={{this.isLoaded}}
      @toggle={{this.expansion.toggle}}
    >
      <:name>
        <span class="ba-badge">plugin</span>
        <span class="ba-label">{{this.plugin.plugin}}</span>
      </:name>
      <:numbers>
        <span class="ba-num"><b>{{brotliLabel this.totals}}</b>
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.totals.raw}}
          <span class="ba-pill">raw</span></span>
      </:numbers>
      <:body>
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
          <div class="ba-hint">
            Loaded on demand, when a url matches.
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
      </:body>
    </Row>
  </template>
}

export function pluginMatches(graph, plugin, filter) {
  if (!filter) {
    return true;
  }
  return (
    matches(plugin.plugin, filter) ||
    Object.keys(plugin.chunks).some((f) => graph.chunkMatches(f, filter)) ||
    Object.values(plugin.routeBundles)
      .flat()
      .some((b) => matches(b.url, filter))
  );
}
