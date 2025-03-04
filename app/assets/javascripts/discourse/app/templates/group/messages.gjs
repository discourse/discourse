import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import iN from "discourse/helpers/i18n";
export default RouteTemplate(<template>
  <section class="user-secondary-navigation">
    <HorizontalOverflowNav class="messages-nav">
      <li>
        <LinkTo @route="group.messages.inbox" @model={{@controller.model.name}}>
          {{iN "user.messages.inbox"}}
        </LinkTo>
      </li>
      <li>
        <LinkTo
          @route="group.messages.archive"
          @model={{@controller.model.name}}
        >
          {{iN "user.messages.archive"}}
        </LinkTo>
      </li>
    </HorizontalOverflowNav>
  </section>
  <section class="user-content" id="user-content">
    {{outlet}}
  </section>
</template>);
