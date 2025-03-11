import Component from "@ember/component";
import { filterBy } from "@ember/object/computed";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import reviewableHistoryDescription from "discourse/helpers/reviewable-history-description";
import { i18n } from "discourse-i18n";

export default class ReviewableHistories extends Component {
  @filterBy("histories", "created", false) filteredHistories;

  <template>
    {{#if this.filteredHistories}}
      <table class="reviewable-histories">
        <thead>
          <tr>
            <th colspan="3">{{i18n "review.history.title"}}</th>
          </tr>
        </thead>
        <tbody>
          {{#each this.filteredHistories as |rh|}}
            {{#unless rh.created}}
              <tr>
                <td>
                  {{reviewableHistoryDescription rh}}
                </td>
                <td>
                  <UserLink @user={{this.rs.user}}>
                    {{avatar rh.created_by imageSize="tiny"}}
                    {{rh.created_by.username}}
                  </UserLink>
                </td>
                <td>{{formatDate rh.created_at format="medium"}}</td>
              </tr>
            {{/unless}}
          {{/each}}
        </tbody>
      </table>
    {{/if}}
  </template>
}
