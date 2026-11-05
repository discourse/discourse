import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Shows a newly created API key once, with a summary of what it can do.
 * Yields so the caller can provide the way out of this screen.
 */
export default class GeneratedApiKey extends Component {
  @service toasts;

  get scopeModeLabel() {
    return i18n(`admin.api.scopes.${this.args.details.scopeMode}`);
  }

  @action
  async copyApiKey() {
    await clipboardCopy(this.args.apiKey);
    this.toasts.success({
      data: { message: i18n("admin.api_keys.key_copied_to_clipboard") },
      duration: "short",
    });
  }

  <template>
    <div class="generated-api-key-container">
      <div class="alert alert-warning">
        {{dIcon "triangle-exclamation"}}
        <span>{{i18n "admin.api.not_shown_again"}}</span>
      </div>

      {{#if @details}}
        <div class="generated-api-key__details">
          {{#if @details.description}}
            <div class="generated-api-key__detail-row">
              <span class="generated-api-key__label">{{i18n
                  "admin.api.description"
                }}</span>
              <span>{{@details.description}}</span>
            </div>
          {{/if}}
          <div class="generated-api-key__detail-row">
            <span class="generated-api-key__label">{{i18n
                "admin.api.scope_mode"
              }}</span>
            <span>{{this.scopeModeLabel}}</span>
          </div>
          {{#if @details.scopes}}
            <div class="generated-api-key__detail-row">
              <span class="generated-api-key__label">{{i18n
                  "admin.api.scopes.title"
                }}</span>
              <span class="generated-api-key__scope-badges">
                {{#each @details.scopes as |scope|}}
                  <span class="generated-api-key__scope-badge">
                    {{scope.scope_id}}
                    {{#each scope.params as |paramName|}}
                      {{#if (get scope paramName)}}
                        <span
                          class="generated-api-key__scope-param"
                        >({{paramName}}:
                          {{get scope paramName}})</span>
                      {{/if}}
                    {{/each}}
                  </span>
                {{/each}}
              </span>
            </div>
          {{/if}}
        </div>
      {{/if}}

      <div class="generated-api-key__key-row">
        <code class="generated-api-key">{{@apiKey}}</code>
        <DButton
          class="btn-default generated-api-key__copy-btn"
          @action={{this.copyApiKey}}
          @icon="copy"
          @label="admin.api_keys.copy_key"
        />
      </div>

      {{yield}}
    </div>
  </template>
}
