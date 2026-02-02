/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";

@tagName("")
export default class AdminReportInlineTable extends Component {
  <template>
    <div class="admin-report-inline-table" ...attributes>
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
    </div>
  </template>
}
