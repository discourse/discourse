import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";

let globalI = 1;

function stringifyValue(value) {
  try {
    if (value === undefined) {
      return "undefined";
    } else if (value === null) {
      return "null";
    } else if (["string", "number"].includes(typeof value)) {
      return JSON.stringify(value);
    } else if (typeof value === "boolean") {
      return String(value);
    } else if (Array.isArray(value)) {
      return `Array (${value.length} items)`;
    } else if (String(value).startsWith("class ")) {
      return `class ${value.name} {}`;
    } else if (value.constructor?.name === "function") {
      return `ƒ ${value.name || "function"}(...)`;
    } else if (value.id) {
      return `${value.constructor?.name} { id: ${value.id} }`;
    } else {
      return `${value.constructor?.name} {}`;
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("Unable to stringify value:", value, e);
    return "(unable to stringify)";
  }
}

export default class ArgsTable extends Component {
  get renderArgs() {
    return Object.entries(this.args.outletArgs).map(([key, value]) => {
      return {
        key,
        value: stringifyValue(value),
        originalValue: value,
      };
    });
  }

  writeToConsole(key, value, event) {
    event.preventDefault();
    window[`arg${globalI}`] = value;
    /* eslint-disable no-console */
    console.log(
      `[plugin outlet debug] \`@${key}\` saved to global \`arg${globalI}\`, and logged below:`
    );
    console.log(value);
    /* eslint-enable no-console */

    globalI++;
  }

  <template>
    {{#each this.renderArgs as |arg|}}
      <div class="key"><span class="fw">@{{arg.key}}</span>:</div>
      <div class="value">
        <span class="fw">{{arg.value}}</span>
        <a
          title="Write to console"
          href=""
          {{on "click" (fn this.writeToConsole arg.key arg.originalValue)}}
        >{{icon "code"}}</a>
      </div>
    {{else}}
      <div class="no-arguments">(no arguments)</div>
    {{/each}}
  </template>
}
