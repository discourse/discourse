import Component from "@glimmer/component";
import { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import GroupCardContents from "discourse/components/group-card-contents";
import UserCardContents from "discourse/components/user-card-contents";
import routeAction from "discourse/helpers/route-action";
import DiscourseURL, { groupPath, userPath } from "discourse/lib/url";
import PluginOutlet from "./plugin-outlet";

export default class CardContainer extends Component {
  @service site;
  @controller topic;

  @action
  filterPosts(user) {
    this.topic.send("filterParticipant", user);
  }

  @action
  showUser(user) {
    DiscourseURL.routeTo(userPath(user.username_lower));
  }

  @action
  showGroup(group) {
    DiscourseURL.routeTo(groupPath(group.name));
  }

  <template>
    {{#if this.site.mobileView}}
      <div class="card-cloak hidden"></div>
    {{/if}}

    <PluginOutlet @name="user-card-content-container">
      <UserCardContents
        @topic={{this.topic.model}}
        @showUser={{this.showUser}}
        @filterPosts={{this.filterPosts}}
        @composePrivateMessage={{routeAction "composePrivateMessage"}}
        role="dialog"
      />
    </PluginOutlet>

    <GroupCardContents
      @topic={{this.topic.model}}
      @showUser={{this.showUser}}
      @showGroup={{this.showGroup}}
    />
  </template>
}
