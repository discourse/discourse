import { LinkTo } from "@ember/routing";
import UserStream from "discourse/components/user-stream";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="user-drafts-header">
    {{#if @controller.model.discarded}}
      <LinkTo class="user-drafts-header__link" @route="userActivity.drafts">
        {{dIcon "arrow-left"}}
        {{i18n "drafts.discarded.back"}}
      </LinkTo>
      <p class="user-drafts-header__description">
        {{@controller.model.description}}
      </p>
    {{else if @controller.model.showDiscardedLink}}
      <LinkTo
        class="user-drafts-header__link"
        @route="userActivity.discardedDrafts"
      >
        {{dIcon "clock-rotate-left"}}
        {{i18n "drafts.discarded.title"}}
      </LinkTo>
    {{/if}}
  </div>

  {{#if @controller.model.stream.noContent}}
    {{#unless @controller.model.stream.loading}}
      <DEmptyState
        @body={{@controller.model.emptyState.body}}
        @title={{@controller.model.emptyState.title}}
      />
    {{/unless}}
  {{/if}}

  <UserStream @stream={{@controller.model.stream}} />
</template>
