import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { barWidth, fmt, matches, routeName, stem } from "./analysis";

// One expandable chunk row. `@root` renders it as the minimal "dynamic
// entrypoint root" header; `@added` flags it as new vs. the initial load.
export default class ChunkRow extends Component {
  @tracked open = false;

  get chunk() {
    return this.args.analysis.chunks[this.args.file];
  }

  get route() {
    return routeName(this.chunk);
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

  get visibleModules() {
    return this.chunk.modules.filter((m) => matches(m.id, this.args.filter));
  }

  @action
  toggle() {
    this.open = !this.open;
  }

  <template>
    <div class="ba-row {{if this.open 'open'}}">
      <button type="button" class="ba-head" {{on "click" this.toggle}}>
        <span class="ba-name">
          <span class="ba-tw">▶</span>
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
            <span class="ba-label root">dynamic entrypoint root</span>
          {{else}}
            <span class="ba-label" title={{@file}}>
              {{this.stemmed}}
              <span class="ba-pill">· {{this.chunk.moduleCount}} modules</span>
            </span>
          {{/if}}
        </span>
        <span class="ba-num">{{fmt this.chunk.brotliSize}}
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.chunk.rawSize}}
          <span class="ba-pill">raw</span></span>
        <span class="ba-num pill">
          {{#unless @root}}{{this.usedBy.length}} ep{{/unless}}
        </span>
      </button>
      {{#if this.open}}
        <div class="ba-body">
          <div class="ba-pill" style="margin:2px 0 6px">
            Used by entrypoints:
            {{this.usedByLabel}}
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
