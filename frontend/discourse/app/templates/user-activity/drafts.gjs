import { LinkTo } from "@ember/routing";
import UserStream from "discourse/components/user-stream";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.model.stream.discarded}}
    <div class="user-drafts-header">
      <LinkTo class="user-drafts-header__link" @route="userActivity.drafts">
        {{dIcon "arrow-left"}}
        {{i18n "drafts.discarded.back"}}
      </LinkTo>
      <p class="user-drafts-header__description">
        {{i18n "drafts.discarded.description" count=@controller.retentionDays}}
      </p>
    </div>
  {{else if @controller.retentionDays}}
    <div class="user-drafts-header">
      <LinkTo
        class="user-drafts-header__link"
        @route="userActivity.discardedDrafts"
      >
        {{dIcon "clock-rotate-left"}}
        {{i18n "drafts.discarded.title"}}
      </LinkTo>
    </div>
  {{/if}}

  {{#if @controller.model.stream.noContent}}
    <DEmptyState
      @body={{@controller.model.emptyState.body}}
      @title={{@controller.model.emptyState.title}}
    />
  {{else}}
    <UserStream @stream={{@controller.model.stream}} />
  {{/if}}
</template>
