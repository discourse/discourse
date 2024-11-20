import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class FKErrorsSummary extends Component {
  concatErrors(errors) {
    return errors.join(", ");
  }

  get hasErrors() {
    return Object.keys(this.args.errors).length > 0;
  }

  normalizeName(name) {
    return name.replace(/\./g, "-");
  }

  <template>
    {{#if this.hasErrors}}
      <div class="form-kit__errors-summary" aria-live="assertive" ...attributes>
        <h2 class="form-kit__errors-summary-title">
          {{icon "triangle-exclamation"}}
          {{i18n "form_kit.errors_summary_title"}}
        </h2>

        <ul class="form-kit__errors-summary-list">
          {{#each-in @errors as |name error|}}
            <li>
              <a
                rel="noopener noreferrer"
                href={{concat "#control-" (this.normalizeName name)}}
              >{{error.title}}</a>:
              {{this.concatErrors error.messages}}
            </li>
          {{/each-in}}
        </ul>
      </div>
    {{/if}}
  </template>
}
