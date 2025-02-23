import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ReviewableCreatedByName = <template>
  <div class="names">
    <span class="username">
      {{#if @user}}
        <UserLink @user={{@user}}>{{@user.username}}</UserLink>
        {{#if @user.silenced}}
          {{icon "ban" title="user.silenced_tooltip"}}
        {{/if}}
      {{else}}
        {{i18n "review.deleted_user"}}
      {{/if}}
    </span>
    <PluginOutlet
      @name="after-reviewable-post-user"
      @connectorTagName="div"
      @outletArgs={{hash user=@user}}
    />
  </div>
</template>;

export default ReviewableCreatedByName;
