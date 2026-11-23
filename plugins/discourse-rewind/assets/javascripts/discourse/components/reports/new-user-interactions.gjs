import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const CROWD_LIMIT = 120;
const PERSON_VARIANTS = 8;

export default class NewUserInteractions extends Component {
  get count() {
    return this.args.report.data.unique_new_users;
  }

  get memberText() {
    return i18n("discourse_rewind.reports.new_user_interactions.new_member", {
      count: this.count,
    });
  }

  get contributionsText() {
    return i18nForOwner(
      "discourse_rewind.reports.new_user_interactions.contributions_helped",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  /**
   * One tiny person per newcomer, capped so a huge year stays a crowd, not a wall.
   */
  get crowd() {
    return Array.from(
      { length: Math.min(this.count, CROWD_LIMIT) },
      (_, index) => (index * 5 + Math.floor(index / 3)) % PERSON_VARIANTS
    );
  }

  <template>
    <div class="rewind-report-page --new-user-interactions">
      <h2 class="rewind-report-title">{{this.contributionsText}}</h2>
      <div class="rewind-newcomers">
        <p class="rewind-big rewind-newcomers__count">{{this.memberText}}</p>
        <ul aria-hidden="true" class="rewind-newcomers__crowd">
          {{#each this.crowd as |variant|}}
            <li class="rewind-newcomers__person" data-variant={{variant}}></li>
          {{/each}}
        </ul>
      </div>
    </div>
  </template>
}
