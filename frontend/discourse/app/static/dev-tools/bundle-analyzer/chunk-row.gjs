import { cached } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { barWidth, fmt, matches, routeName, stem } from "./analysis";
import ExpandableRow from "./expandable-row";

// One expandable chunk row. `@root` marks the card's own chunk rather than one
// it pulls in; `@added` flags it as new vs. the initial load.
export default class ChunkRow extends ExpandableRow {
  get chunk() {
    return this.args.analysis.chunks[this.args.file];
  }

  get route() {
    return routeName(this.chunk);
  }

  get isLoaded() {
    return this.args.loaded?.has(this.args.file);
  }

  get stemmed() {
    return stem(this.args.file);
  }

  get usedBy() {
    return this.args.analysis.usedByEntries[this.args.file] || [];
  }

  get usedByLabel() {
    return this.usedBy.length ? this.usedBy.map(stem).join(", ") : "—";
  }

  get maxModule() {
    return this.chunk.modules.length ? this.chunk.modules[0].renderedLength : 1;
  }

  @cached
  get visibleModules() {
    return this.chunk.modules.filter((m) => matches(m.id, this.args.filter));
  }

  // A filter matching a module path inside this chunk opens it, revealing the
  // matching source path without a click.
  get autoExpanded() {
    return !!this.args.filter && this.visibleModules.length > 0;
  }

  get brotliLabel() {
    const size = this.args.analysis.brotliOf(this.args.file);
    return size == null ? "—" : fmt(size);
  }

  <template>
    <div
      class="ba-row {{if this.expanded 'open'}} {{if this.isLoaded 'loaded'}}"
    >
      <button
        aria-expanded={{if this.expanded "true" "false"}}
        class="ba-head"
        type="button"
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
          {{#unless @root}}
            {{#if this.chunk.isEntry}}
              <span class="ba-badge entry">entry</span>
            {{/if}}
            {{#if this.route}}
              <span class="ba-badge route">route: {{this.route}}</span>
            {{else if this.chunk.isDynamicEntry}}
              <span class="ba-badge dyn">dynamic</span>
            {{/if}}
            {{#if @added}}
              <span class="ba-badge add">added</span>
            {{/if}}
          {{/unless}}
          {{#if @root}}
            <span class="ba-label root">entrypoint chunk</span>
          {{else}}
            <span class="ba-label" title={{@file}}>
              {{this.stemmed}}
              <span class="ba-pill">·
                {{this.chunk.modules.length}}
                modules</span>
            </span>
          {{/if}}
        </span>
        <span class="ba-num">{{this.brotliLabel}}
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.chunk.rawSize}}
          <span class="ba-pill">raw</span></span>
      </button>
      {{#if this.expanded}}
        <div class="ba-body">
          <div class="ba-pill" style="margin:2px 0 6px">
            Used by entrypoints:
            {{this.usedByLabel}}
          </div>
          <div class="ba-pill" style="margin-bottom:4px">
            Module sizes are source bytes as rendered into the chunk, before it
            is minified — they explain proportions, not transfer size.
          </div>
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
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
