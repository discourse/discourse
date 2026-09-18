import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

const AdminReportInlineTable = <template>
  <div class="admin-report-inline-table" ...attributes>
    <div class="table-container">
      {{#each @model.data as |data|}}
        <a class="table-cell user-{{data.key}}" href={{data.url}}>
          <span class="label">
            {{#if data.icon}}
              {{dIcon data.icon}}
            {{/if}}
            {{data.x}}
          </span>
          <span class="value">
            {{dNumber data.y}}
          </span>
        </a>
      {{/each}}
    </div>
  </div>
</template>;

export default AdminReportInlineTable;
