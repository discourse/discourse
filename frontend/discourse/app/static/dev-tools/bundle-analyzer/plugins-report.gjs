import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fmt } from "./analysis";
import BrotliSizes from "./brotli-sizes";
import PluginCard, { pluginMatches } from "./plugin-card";

export default class PluginsReport extends Component {
  @tracked filter = "";

  brotli = new BrotliSizes(this.args.analysis);

  willDestroy() {
    super.willDestroy(...arguments);
    this.brotli.teardown();
  }

  get analysis() {
    return this.args.analysis;
  }

  get totals() {
    return this.analysis.totals(Object.keys(this.analysis.chunks));
  }

  @cached
  get visible() {
    return this.analysis.plugins
      .filter((p) => pluginMatches(p, this.filter))
      .sort(
        (a, b) =>
          this.analysis.totalsFor(b).raw - this.analysis.totalsFor(a).raw
      );
  }

  @action
  updateFilter(event) {
    this.filter = event.target.value.trim().toLowerCase();
  }

  <template>
    <div class="bundle-analyzer">
      <div class="ba-header">
        <span class="ba-sub">
          {{this.analysis.plugins.length}}
          plugins ·
          {{this.analysis.chunkCount}}
          chunks ·
          {{if this.totals.brotliReady (fmt this.totals.brotli) "…"}}
          br /
          {{fmt this.totals.raw}}
          raw · generated
          {{this.analysis.data.generatedAt}}
        </span>
        {{#unless this.analysis.brotliDone}}
          <span class="ba-sub">
            computing brotli…
            {{this.analysis.brotliCount}}/{{this.analysis.chunkCount}}
          </span>
        {{/unless}}
      </div>

      <div class="ba-toolbar">
        <input
          placeholder="Filter plugins / chunks / modules / routes…"
          type="search"
          {{on "input" this.updateFilter}}
        />
      </div>

      <section>
        <div class="ba-hint">
          Each plugin is built on its own, so these sizes are separate from
          core's and from each other. A route bundle counts only what it adds on
          top of the entrypoint that loads it.
        </div>
        <div>
          {{#each this.visible as |p|}}
            <PluginCard
              @analysis={{this.analysis}}
              @filter={{this.filter}}
              @plugin={{p}}
            />
          {{else}}
            <div class="ba-empty">No matches.</div>
          {{/each}}
        </div>
      </section>
    </div>
  </template>
}
