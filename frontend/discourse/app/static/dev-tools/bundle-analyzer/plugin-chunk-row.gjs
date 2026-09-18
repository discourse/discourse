import { on } from "@ember/modifier";
import { barWidth, fmt, matches } from "./analysis";
import ExpandableRow from "./expandable-row";

// One chunk of a plugin, expandable to the source modules inside it.
export default class PluginChunkRow extends ExpandableRow {
  get chunk() {
    return this.args.chunk;
  }

  get brotli() {
    return this.args.analysis.brotliOf(this.chunk.file);
  }

  get maxModule() {
    return this.chunk.modules[0]?.renderedLength || 1;
  }

  get visibleModules() {
    return this.chunk.modules.filter((m) => matches(m.id, this.args.filter));
  }

  // A filter matching a module path inside this chunk opens it, revealing the
  // matching source path without a click.
  get autoExpanded() {
    return (
      !!this.args.filter &&
      this.chunk.modules.some((m) => matches(m.id, this.args.filter))
    );
  }

  <template>
    <div class="ba-row {{if this.expanded 'open'}}">
      <button
        class="ba-head"
        style="grid-template-columns:1fr 130px 130px 70px"
        type="button"
        {{on "click" this.toggle}}
      >
        <span class="ba-name">
          <span class="ba-tw">▶</span>
          {{#if this.chunk.isEntry}}
            <span class="ba-badge entry">entry</span>
          {{/if}}
          <span class="ba-label" title={{this.chunk.file}}>
            {{this.chunk.file}}
            <span class="ba-pill">· {{this.chunk.moduleCount}} modules</span>
          </span>
        </span>
        <span class="ba-num">{{if this.brotli (fmt this.brotli) "…"}}
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.chunk.rawSize}}
          <span class="ba-pill">raw</span></span>
        <span class="ba-num pill"></span>
      </button>
      {{#if this.expanded}}
        <div class="ba-body">
          {{#each this.visibleModules as |m|}}
            <div class="ba-mod" title={{m.id}}>
              <div>
                <div class="ba-mname">{{m.id}}</div>
                <div class="ba-bar">
                  <span
                    style={{barWidth m.renderedLength this.maxModule}}
                  ></span>
                </div>
              </div>
              <div class="ba-num">{{fmt m.renderedLength}}</div>
            </div>
          {{else}}
            <div class="ba-site pill">No modules recorded.</div>
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
