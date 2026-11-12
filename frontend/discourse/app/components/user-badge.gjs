import Component from "@glimmer/component";
import DBadgeButton from "discourse/ui-kit/d-badge-button";

export default class UserBadge extends Component {
  get showGrantCount() {
    return this.args.count > 1;
  }

  get badgeUrl() {
    // NOTE: I tried using a link-to helper here but the queryParams mean it fails
    let username = this.args.user?.username_lower;
    username = username ? `?username=${username}` : "";
    return this.args.badge.url + username;
  }

  <template>
    <a class="user-card-badge-link" href={{this.badgeUrl}}>
      <DBadgeButton @badge={{@badge}} @showName={{@showName}}>
        {{#if this.showGrantCount}}
          <span class="count">&nbsp;(&times;{{@count}})</span>
        {{/if}}
      </DBadgeButton>
    </a>
  </template>
}
