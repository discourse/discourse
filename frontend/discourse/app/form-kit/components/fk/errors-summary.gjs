import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class FKErrorsSummary extends Component {
  focusField = (event) => {
    const href = event.currentTarget.getAttribute("href");
    if (!href?.startsWith("#control-")) {
      return;
    }

    const container = document.getElementById(href.slice(1));
    const focusable =
      container?.querySelector(
        '[contenteditable="true"], [contenteditable="plaintext-only"]'
      ) ??
      container?.querySelector(
        "input, select, textarea, button, [tabindex]:not([tabindex='-1'])"
      );

    if (focusable) {
      event.preventDefault();
      let disclosure = focusable.closest("details");
      while (disclosure) {
        disclosure.open = true;
        disclosure = disclosure.parentElement?.closest("details");
      }
      focusable.focus({ preventScroll: true, focusVisible: true });
      focusable.scrollIntoView({
        block: "center",
        behavior: window.matchMedia("(prefers-reduced-motion: reduce)").matches
          ? "instant"
          : "smooth",
      });
    }
  };

  get errorCount() {
    return Object.keys(this.args.errors).length;
  }

  get hasErrors() {
    return this.errorCount > 0;
  }

  concatErrors(errors) {
    return errors.join(", ");
  }

  normalizeName(name) {
    return name.replace(/\./g, "-");
  }

  <template>
    {{#if this.hasErrors}}
      <div aria-live="assertive" class="form-kit__errors-summary" ...attributes>
        <h2 class="form-kit__errors-summary-title">
          {{dIcon "triangle-exclamation"}}
          {{i18n "form_kit.errors_summary_title" count=this.errorCount}}
        </h2>

        <ul class="form-kit__errors-summary-list">
          {{#each-in @errors as |name error|}}
            <li>
              {{! Errors with a title point at a specific control: render the
                  title as a focus-the-field link. Errors without a title are
                  form-level (not tied to a single input) — render the message
                  on its own, with no anchor or label prefix. }}
              {{#if error.title}}
                <a
                  href="#control-{{this.normalizeName name}}"
                  rel="noopener noreferrer"
                  {{on "click" this.focusField}}
                >{{error.title}}</a>:
                {{this.concatErrors error.messages}}
              {{else}}
                {{this.concatErrors error.messages}}
              {{/if}}
            </li>
          {{/each-in}}
        </ul>
      </div>
    {{/if}}
  </template>
}
