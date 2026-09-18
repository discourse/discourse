import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { fmt } from "./analysis";
import PluginCard, { pluginMatches } from "./plugin-card";

export default class PluginsReport extends Component {
  @tracked filter = "";

  get data() {
    return this.args.data;
  }

  @cached
  get visible() {
    return this.data.plugins
      .filter((p) => pluginMatches(p, this.filter))
      .map((p) => ({
        plugin: p,
        raw: Object.values(p.chunks).reduce((n, c) => n + c.rawSize, 0),
      }))
      .sort((a, b) => b.raw - a.raw)
      .map((x) => x.plugin);
  }

  get totalRaw() {
    return this.data.plugins.reduce(
      (n, p) => n + Object.values(p.chunks).reduce((m, c) => m + c.rawSize, 0),
      0
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
          {{this.data.plugins.length}}
          plugins ·
          {{fmt this.totalRaw}}
          raw · generated
          {{this.data.generatedAt}}
        </span>
      </div>

      <div class="ba-toolbar">
        <input
          placeholder="Filter plugins / chunks / routes…"
          type="search"
          {{on "input" this.updateFilter}}
        />
      </div>

      <section>
        <div class="ba-hint">
          Each plugin is built on its own, so these sizes are separate from
          core's and from each other. Sizes are raw bytes, unminified outside
          production.
        </div>
        <div>
          {{#each this.visible as |p|}}
            <PluginCard @filter={{this.filter}} @plugin={{p}} />
          {{else}}
            <div class="ba-empty">No matches.</div>
          {{/each}}
        </div>
      </section>
    </div>
  </template>
}
