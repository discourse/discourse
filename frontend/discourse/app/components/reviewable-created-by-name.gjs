import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DUserLink from "discourse/ui-kit/d-user-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ReviewableCreatedByName = <template>
  <div class="names">
    <span class="username">
      {{#if @user}}
        <DUserLink @user={{@user}}>{{@user.username}}</DUserLink>
        {{#if @user.silenced}}
          {{dIcon "ban" title="user.silenced_tooltip"}}
        {{/if}}
      {{else}}
        {{i18n "review.deleted_user"}}
      {{/if}}
    </span>
    <PluginOutlet
      @name="after-reviewable-post-user"
      @connectorTagName="div"
      @outletArgs={{lazyHash user=@user}}
    />
  </div>
</template>;

export default ReviewableCreatedByName;
