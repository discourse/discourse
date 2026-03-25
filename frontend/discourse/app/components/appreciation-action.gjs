import PluginOutlet from "discourse/components/plugin-outlet";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { userPath } from "discourse/lib/url";
import { eq } from "discourse/truth-helpers";

const AppreciationAction = <template>
  <div
    class="appreciation-action appreciation-action--{{@item.appreciation_type}}"
  >
    {{#if (eq @item.appreciation_type "like")}}
      {{icon "heart"}}
      {{#each @item.acting_users as |actingUser|}}
        <a
          href={{userPath actingUser.username}}
          data-user-card={{actingUser.username}}
          class="avatar-link"
        >
          <div class="avatar-wrapper">
            {{avatar actingUser imageSize="tiny"}}
          </div>
        </a>
      {{/each}}
    {{else}}
      <PluginOutlet
        @name="appreciation-action"
        @outletArgs={{lazyHash item=@item}}
      />
    {{/if}}
  </div>
</template>;

export default AppreciationAction;
