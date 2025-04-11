import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import BadgeButton from "discourse/components/badge-button";
import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default class AdminBadgesIndex extends Component {
  <template>
    <section class="current-badge content-body">
      <h2>{{i18n "admin.badges.badge_intro.title"}}</h2>
      <p>{{i18n "admin.badges.badge_intro.description"}}</p>
    </section>
  </template>
}
