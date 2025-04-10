import Component from "@ember/component";
import BadgeButton from "discourse/components/badge-button";
import { LinkTo } from "@ember/routing";
import { i18n } from "discourse-i18n";

export default class AdminBadgesList extends Component {
  <template>
    <div class="content-list">
      <ul class="admin-badge-list">
        {{#each @badges as |badge|}}
          <li class="admin-badge-list-item">
            <LinkTo
              @route={{@route}}
              @model={{badge.id}}
            >
              <BadgeButton @badge={{badge}} />
              {{#if badge.newBadge}}
                <span class="list-badge">{{i18n
                    "filters.new.lower_title"
                  }}</span>
              {{/if}}
            </LinkTo>
          </li>
        {{/each}}
      </ul>
    </div>
    {{outlet}}
  </template>
}
