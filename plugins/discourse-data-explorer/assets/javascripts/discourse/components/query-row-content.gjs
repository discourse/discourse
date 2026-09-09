import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import getURL from "discourse/lib/get-url";
import HiddenViewComponent from "./result-types/hidden";
import TextViewComponent from "./result-types/text";

const BASE_URI = getURL("");

export default class QueryRowContent extends Component {
  @cached
  get results() {
    return this.args.columnComponents.map((componentDefinition, idx) => {
      const value = this.args.row[idx];

      if (value === null) {
        return { component: TextViewComponent, textValue: "NULL" };
      }

      if (componentDefinition.name === "text") {
        return { component: TextViewComponent, textValue: value.toString() };
      }

      const id = parseInt(value, 10);
      const ctx = { value, id, baseuri: BASE_URI };

      if (componentDefinition.table) {
        ctx[componentDefinition.name] = componentDefinition.table[id];

        if (!ctx[componentDefinition.name]) {
          return {
            component: componentDefinition.hidden?.includes(id)
              ? HiddenViewComponent
              : TextViewComponent,
            textValue: value.toString(),
          };
        }
      }

      if (componentDefinition.name === "url") {
        [ctx.href, ctx.target] = guessUrl(value);
      }

      return {
        component: componentDefinition.component || TextViewComponent,
        ctx,
      };
    });
  }

  <template>
    <tr class="query-result-row">
      {{#each this.results as |result|}}
        <td class="query-result-cell">
          <result.component
            @ctx={{result.ctx}}
            @textValue={{result.textValue}}
          />
        </td>
      {{/each}}
    </tr>
  </template>
}

function guessUrl(columnValue) {
  const [name, dest = columnValue] = String(columnValue).split(/,(.+)/);

  return [dest, name];
}
