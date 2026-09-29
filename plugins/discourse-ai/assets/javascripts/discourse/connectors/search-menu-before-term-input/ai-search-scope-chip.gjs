import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { contextScope } from "../../lib/ai-search-scope";

/**
 * Core only shows a scope chip for a topic or the messages inbox. Combined
 * search scopes to categories, tags and users too, so it names them the same
 * way, and taking the chip off widens the search.
 */
export default class AiSearchScopeChip extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.ai_ask_ai_combined_search_prototype &&
      currentUser?.can_use_ask_ai
    );
  }

  @service aiSearchSession;
  @service search;

  get scope() {
    const scope = contextScope(this.search, {
      inPMInboxContext: false,
      dismissedKey: this.aiSearchSession.dismissedScope?.key,
    });
    return scope?.ownChip ? scope : null;
  }

  get label() {
    return i18n("discourse_ai.ai_search.scope.chip", {
      name: this.scope.label,
    });
  }

  <template>
    {{#if this.scope}}
      <DButton
        class="btn-default btn-small search-context ai-search-scope-chip"
        @action={{fn this.aiSearchSession.dismissScope this.scope}}
        @icon="xmark"
        @title="discourse_ai.ai_search.scope.remove"
        @translatedLabel={{this.label}}
      />
    {{/if}}
  </template>
}
