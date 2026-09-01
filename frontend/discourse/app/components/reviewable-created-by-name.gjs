import Component from "@glimmer/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { longDate } from "discourse/lib/formatter";
import {
  penaltyIcon,
  penaltyPastTense,
} from "discourse/lib/reviewable-penalty";
import DUserLink from "discourse/ui-kit/d-user-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ReviewableCreatedByName extends Component {
  get penalties() {
    return (this.args.penalties ?? []).map((penalty) => ({
      icon: penaltyIcon(penalty.kind),
      title: this.#title(penalty),
    }));
  }

  #title(penalty) {
    const state = penaltyPastTense(penalty.kind);

    return penalty.forever
      ? i18n(`user.${state}_permanently`)
      : i18n(`user.${state}_notice`, { date: longDate(penalty.expires_at) });
  }

  <template>
    <div class="names">
      <span class="username">
        {{#if @user}}
          <DUserLink @user={{@user}}>{{@user.username}}</DUserLink>
          {{#each this.penalties as |penalty|}}
            {{dIcon
              penalty.icon
              class="reviewable-penalty-icon"
              translatedTitle=penalty.title
            }}
          {{/each}}
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
  </template>
}
