import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class MobileTabBarReviewBadge extends Component {
  @service currentUser;

  <template>
    {{#if this.currentUser.reviewable_count}}
      <span class="mobile-tab-bar__count">
        {{this.currentUser.reviewable_count}}
      </span>
    {{/if}}
  </template>
}
