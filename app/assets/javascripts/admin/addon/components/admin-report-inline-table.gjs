import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";

@classNames("admin-report-inline-table")
export default class AdminReportInlineTable extends Component {
  <template>
    <div class="table-container">
      {{#each this.model.data as |data|}}
        <a class="table-cell user-{{data.key}}" href={{data.url}}>
          <span class="label">
            {{#if data.icon}}
              {{icon data.icon}}
            {{/if}}
            {{data.x}}
          </span>
          <span class="value">
            {{number data.y}}
          </span>
        </a>
      {{/each}}
    </div>
  </template>
}
