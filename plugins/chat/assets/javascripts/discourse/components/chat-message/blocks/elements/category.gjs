import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class CategoryElement extends Component {
  get boxStyle() {
    let style = `--category-badge-color: #${this.args.definition.color}`;
    if (this.args.definition.parent_color) {
      style += `; --parent-category-badge-color: #${this.args.definition.parent_color}`;
    }
    return htmlSafe(style);
  }

  get parentBadgeStyle() {
    return this.args.definition.parent_color
      ? htmlSafe(
          `--category-badge-color: #${this.args.definition.parent_color}`
        )
      : null;
  }

  <template>
    <div class="block__category" style={{this.boxStyle}}>
      <div class="block__category-inner">
        <div class="block__category-heading">
          {{#if @definition.url}}
            <a href={{@definition.url}} class="block__category-link">
              <span class="badge-category --style-square">
                <span class="badge-category__name">{{@definition.title}}</span>
              </span>
            </a>
          {{else}}
            <span class="badge-category --style-square">
              <span class="badge-category__name">{{@definition.title}}</span>
            </span>
          {{/if}}
        </div>
        {{#if @definition.parent_name}}
          <div class="block__category-parent">
            <span
              class="badge-category --style-square"
              style={{this.parentBadgeStyle}}
            >
              <span
                class="badge-category__name"
              >{{@definition.parent_name}}</span>
            </span>
          </div>
        {{/if}}
        {{#if @definition.description}}
          <div class="block__category-description">
            {{@definition.description}}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
