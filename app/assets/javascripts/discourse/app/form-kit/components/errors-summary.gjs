import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { makeArray } from "discourse-common/lib/helpers";

export default class FKErrorsSummary extends Component {
  get fields() {
    return makeArray(this.args.fields);
  }

  concatErrors(errors) {
    return errors.join(", ");
  }

  <template>
    {{#if this.fields.length}}
      <div class="form-kit__errors-summary" aria-live="assertive" ...attributes>
        <h2 class="form-kit__errors-summary-title">
          {{icon "exclamation-triangle"}}
          {{i18n "form_kit.errors_summary_title"}}
        </h2>

        <ul class="form-kit__errors-summary-list">
          {{#each this.fields as |field|}}
            <li>
              {{field.title}}:
              {{this.concatErrors field.visibleErrors}}
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}
  </template>
}
