import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { gt } from "truth-helpers";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { makeArray } from "discourse-common/lib/helpers";

export default class FKErrorsSummary extends Component {
  get errors() {
    return makeArray(this.args.errors);
  }

  concatErrors(errors) {
    return errors.join(", ");
  }

  <template>
    {{#if (gt this.errors.length 1)}}
      <div class="form-kit__errors-summary" aria-live="assertive" ...attributes>
        <h2 class="form-kit__errors-summary-title">
          {{icon "exclamation-triangle"}}
          {{i18n "form_kit.errors_summary_title"}}
        </h2>

        <ul class="form-kit__errors-summary-list">
          {{#each this.errors as |error|}}
            <li>
              <a
                rel="noopener noreferrer"
                href={{concat "#control-" error.name}}
              >{{error.name}}</a>:
              {{error.message}}
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}
  </template>
}
