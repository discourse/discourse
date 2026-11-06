import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import {
  barWidth,
  fileName,
  fmt,
  label,
  matches,
  routeName,
  sizeOrDash,
} from "../models/analysis.js";
import Expansion from "../models/expansion.js";
import Row from "./row.gjs";

// One expandable chunk row. `@root` marks the card's own chunk rather than one
// it pulls in.
export default class ChunkRow extends Component {
  // A filter matching a module inside this chunk opens it on that module.
  expansion = new Expansion({
    defaultTo: () => !!this.args.filter && this.visibleModules.length > 0,
    filter: () => this.args.filter ?? "",
  });

  get chunk() {
    return this.args.analysis.chunks[this.args.file];
  }

  get route() {
    return routeName(this.chunk);
  }

  get isLoaded() {
    return this.args.loaded?.has(this.args.file);
  }

  get label() {
    return label(this.chunk);
  }

  get fileName() {
    return fileName(this.args.file);
  }

  get usedBy() {
    return this.args.analysis.usedByEntries[this.args.file] || [];
  }

  get usedByLabel() {
    return this.usedBy.length
      ? this.usedBy.map((f) => label(this.args.analysis.chunks[f])).join(", ")
      : "—";
  }

  get maxModule() {
    return this.chunk.modules.length ? this.chunk.modules[0].renderedLength : 1;
  }

  @cached
  get visibleModules() {
    return this.chunk.modules.filter((m) => matches(m.id, this.args.filter));
  }

  get brotliLabel() {
    return sizeOrDash(this.args.analysis.brotliOf(this.args.file));
  }

  <template>
    <Row
      @expanded={{this.expansion.expanded}}
      @loaded={{this.isLoaded}}
      @toggle={{this.expansion.toggle}}
    >
      <:name>
        {{#unless @root}}
          {{#if this.chunk.isEntry}}
            <span class="ba-badge">entry</span>
          {{/if}}
          {{#if this.route}}
            <span class="ba-badge route">route: {{this.route}}</span>
          {{else if this.chunk.isDynamicEntry}}
            <span class="ba-badge">dynamic</span>
          {{/if}}
          {{#if @added}}
            <span class="ba-badge add">added</span>
          {{/if}}
        {{/unless}}
        {{#if @root}}
          <span class="ba-label root">entrypoint chunk</span>
        {{else}}
          <span class="ba-label" title={{@file}}>
            {{this.label}}
            <span class="ba-pill">·
              {{this.chunk.modules.length}}
              modules</span>
          </span>
        {{/if}}
      </:name>
      <:numbers>
        <span class="ba-num">{{this.brotliLabel}}
          <span class="ba-pill">br</span></span>
        <span class="ba-num muted">{{fmt this.chunk.rawSize}}
          <span class="ba-pill">raw</span></span>
      </:numbers>
      <:body>
        <div class="ba-site">file
          <code>{{this.fileName}}</code>
        </div>
        <div class="ba-note">
          Used by
          {{this.usedByLabel}}
        </div>
        <div class="ba-note">
          Source bytes, before minifying.
        </div>
        {{#each this.visibleModules as |m|}}
          <div class="ba-mod" title={{m.id}}>
            <div>
              <div class="ba-mname">{{m.id}}</div>
              <div class="ba-bar">
                <span style={{barWidth m.renderedLength this.maxModule}}></span>
              </div>
            </div>
            <div class="ba-num">{{fmt m.renderedLength}}</div>
          </div>
        {{/each}}
      </:body>
    </Row>
  </template>
}
