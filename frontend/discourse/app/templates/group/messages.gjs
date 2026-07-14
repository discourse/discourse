import { LinkTo } from "@ember/routing";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import { i18n } from "discourse-i18n";

export default <template>
  <section class="user-secondary-navigation">
    <DHorizontalOverflowNav class="messages-nav">
      <li>
        <LinkTo @route="group.messages.inbox" @model={{@controller.model.name}}>
          {{i18n "user.messages.inbox"}}
        </LinkTo>
      </li>
      <li>
        <LinkTo
          @route="group.messages.archive"
          @model={{@controller.model.name}}
        >
          {{i18n "user.messages.archive"}}
        </LinkTo>
      </li>
    </DHorizontalOverflowNav>
  </section>
  <section class="user-content" id="user-content">
    {{outlet}}
  </section>
</template>
