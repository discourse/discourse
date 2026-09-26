import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import AdminBadgesList from "discourse/admin/components/admin-badges-list";
import { i18n } from "discourse-i18n";
import AdminBadgesService from "discourse/admin/services/admin-badges";

export default class AdminBadgesIndex extends Component {
  @service(() => AdminBadgesService) adminBadges;

  get badges() {
    return this.adminBadges.badges;
  }

  <template>
    <AdminBadgesList @badges={{this.badges}} />
    <section class="current-badge content-body">
      <h2>{{i18n "admin.badges.badge_intro.title"}}</h2>
      <p>{{i18n "admin.badges.badge_intro.description"}}</p>
    </section>
  </template>
}
