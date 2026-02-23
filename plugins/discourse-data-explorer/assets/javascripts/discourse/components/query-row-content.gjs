import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { classify } from "@ember/string";
import getURL from "discourse/lib/get-url";
import { escapeExpression } from "discourse/lib/utilities";
import TextViewComponent from "./result-types/text";

export default class QueryRowContent extends Component {
  @cached
  get results() {
    return this.args.columnComponents.map((componentDefinition, idx) => {
      const value = this.args.row[idx],
        id = parseInt(value, 10);

      const ctx = {
        value,
        id,
        baseuri: getURL(""),
      };

      if (this.args.row[idx] === null) {
        return {
          component: TextViewComponent,
          textValue: "NULL",
        };
      } else if (componentDefinition.name === "text") {
        return {
          component: TextViewComponent,
          textValue: escapeExpression(this.args.row[idx].toString()),
        };
      }

      const lookupFunc =
        this.args[`lookup${classify(componentDefinition.name)}`];
      if (lookupFunc) {
        ctx[componentDefinition.name] = lookupFunc.call(this.args, id);
      }

      if (componentDefinition.name === "url") {
        let [url, name] = guessUrl(value);
        ctx["href"] = url;
        ctx["target"] = name;
      }

      try {
        return {
          component: componentDefinition.component || TextViewComponent,
          ctx,
        };
      } catch {
        return "error";
      }
    });
  }

  <template>
    <tr class="query-result-row">
      {{#each this.results as |result|}}
        <td class="query-result-cell">
          <result.component
            @ctx={{result.ctx}}
            @params={{result.params}}
            @textValue={{result.textValue}}
          />
        </td>
      {{/each}}
    </tr>
  </template>
}

function guessUrl(columnValue) {
  let [dest, name] = [columnValue, columnValue];

  const split = columnValue.split(/,(.+)/);

  if (split.length > 1) {
    name = split[0];
    dest = split[1];
  }

  return [dest, name];
}
