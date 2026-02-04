import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class FKErrorsSummary extends Component {
  focusField = (event) => {
    const href = event.currentTarget.getAttribute("href");
    if (!href?.startsWith("#control-")) {
      return;
    }

    const container = document.getElementById(href.slice(1));
    const focusable = container?.querySelector(
      "input, select, textarea, button, [tabindex]:not([tabindex='-1'])"
    );

    if (focusable) {
      event.preventDefault();
      focusable.focus({ preventScroll: true, focusVisible: true });
      focusable.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  };

  concatErrors(errors) {
    return errors.join(", ");
  }

  get errorCount() {
    return Object.keys(this.args.errors).length;
  }

  get hasErrors() {
    return this.errorCount > 0;
  }

  normalizeName(name) {
    return name.replace(/\./g, "-");
  }

  <template>
    {{#if this.hasErrors}}
      <div class="form-kit__errors-summary" aria-live="assertive" ...attributes>
        <h2 class="form-kit__errors-summary-title">
          {{icon "triangle-exclamation"}}
          {{i18n "form_kit.errors_summary_title" count=this.errorCount}}
        </h2>

        <ul class="form-kit__errors-summary-list">
          {{#each-in @errors as |name error|}}
            <li>
              <a
                rel="noopener noreferrer"
                href="#control-{{this.normalizeName name}}"
                {{on "click" this.focusField}}
              >{{error.title}}</a>:
              {{this.concatErrors error.messages}}
            </li>
          {{/each-in}}
        </ul>
      </div>
    {{/if}}
  </template>
}
