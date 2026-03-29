import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import avatar from "discourse/helpers/avatar";
import { userPath } from "discourse/lib/url";

export default class DiscourseBoostsAppreciationAction extends Component {
  get shouldRender() {
    return this.args.outletArgs.item?.appreciation_type === "boost";
  }

  get actingUser() {
    return this.args.outletArgs.item?.acting_user;
  }

  get cooked() {
    return this.args.outletArgs.item?.metadata?.cooked;
  }

  <template>
    {{#if this.shouldRender}}
      <a
        href={{userPath this.actingUser.username}}
        data-user-card={{this.actingUser.username}}
        class="discourse-boosts-activity__avatar"
      >
        {{avatar this.actingUser imageSize="tiny"}}
      </a>
      <span class="discourse-boosts-activity__cooked">{{trustHTML
          this.cooked
        }}</span>
    {{/if}}
  </template>
}
