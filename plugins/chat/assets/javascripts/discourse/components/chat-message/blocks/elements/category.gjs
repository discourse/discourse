import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";

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

  get childBadgeStyle() {
    return htmlSafe(`--category-badge-color: #${this.args.definition.color}`);
  }

  get childBadgeClasses() {
    return this.args.definition.parent_name
      ? "--style-square --has-parent"
      : "--style-square";
  }

  <template>
    {{#if @definition.simple}}
      {{! Simple badge style - just the badge, no box }}
      {{#if @definition.url}}
        <a href={{@definition.url}} class="block__category-simple-link">
          <span class="badge-category__wrapper">
            {{#if @definition.parent_name}}
              <span
                class="badge-category --style-square"
                style={{this.parentBadgeStyle}}
              >
                <span
                  class="badge-category__name"
                >{{@definition.parent_name}}</span>
              </span>
            {{/if}}
            <span
              class={{concatClass "badge-category" this.childBadgeClasses}}
              style={{this.childBadgeStyle}}
            >
              <span class="badge-category__name">{{@definition.title}}</span>
            </span>
          </span>
        </a>
      {{else}}
        <span class="badge-category__wrapper">
          {{#if @definition.parent_name}}
            <span
              class="badge-category --style-square"
              style={{this.parentBadgeStyle}}
            >
              <span
                class="badge-category__name"
              >{{@definition.parent_name}}</span>
            </span>
          {{/if}}
          <span
            class={{concatClass "badge-category" this.childBadgeClasses}}
            style={{this.childBadgeStyle}}
          >
            <span class="badge-category__name">{{@definition.title}}</span>
          </span>
        </span>
      {{/if}}
    {{else}}
      {{! Box style - full category box with description }}
      <div class="block__category" style={{this.boxStyle}}>
        <div class="block__category-inner">
          <div class="block__category-heading">
            {{#if @definition.url}}
              <a href={{@definition.url}} class="block__category-link">
                <span class="badge-category__wrapper">
                  {{#if @definition.parent_name}}
                    <span
                      class="badge-category --style-square"
                      style={{this.parentBadgeStyle}}
                    >
                      <span
                        class="badge-category__name"
                      >{{@definition.parent_name}}</span>
                    </span>
                  {{/if}}
                  <span
                    class={{concatClass
                      "badge-category"
                      this.childBadgeClasses
                    }}
                  >
                    <span
                      class="badge-category__name"
                    >{{@definition.title}}</span>
                  </span>
                </span>
              </a>
            {{else}}
              <span class="badge-category__wrapper">
                {{#if @definition.parent_name}}
                  <span
                    class="badge-category --style-square"
                    style={{this.parentBadgeStyle}}
                  >
                    <span
                      class="badge-category__name"
                    >{{@definition.parent_name}}</span>
                  </span>
                {{/if}}
                <span
                  class={{concatClass "badge-category" this.childBadgeClasses}}
                >
                  <span
                    class="badge-category__name"
                  >{{@definition.title}}</span>
                </span>
              </span>
            {{/if}}
          </div>
          {{#if @definition.description}}
            <div class="block__category-description">
              {{@definition.description}}
            </div>
          {{/if}}
        </div>
      </div>
    {{/if}}
  </template>
}
