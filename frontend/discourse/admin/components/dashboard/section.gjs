import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import DButton from "discourse/components/d-button";

const LAYOUTS = ["column", "row", "grid"];

export default class DashboardSection extends Component {
  get bordered() {
    return this.args.bordered ?? true;
  }

  get layoutModifier() {
    return `--${LAYOUTS.includes(this.args.layout) ? this.args.layout : "column"}`;
  }

  <template>
    <section class="db-section" ...attributes>
      <div class="db-section__header-row">
        <h2 class="db-section__header">{{@title}}</h2>
        {{#if @headerActionIcon}}
          <div class="db-section__header-action">
            <DButton
              @icon={{@headerActionIcon}}
              @action={{@headerAction}}
              class="btn-transparent no-text"
            />
          </div>
        {{/if}}
      </div>

      {{#if @description}}
        <p class="db-section__intro">{{@description}}</p>
      {{/if}}

      <div
        class={{concat
          "db-section__wrapper "
          this.layoutModifier
          (unless this.bordered " --no-border")
        }}
      >
        {{yield (hash startDate=@startDate endDate=@endDate)}}
      </div>
    </section>
  </template>
}
