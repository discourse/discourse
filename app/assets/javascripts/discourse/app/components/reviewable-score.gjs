import Component from "@ember/component";
import { gt } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import reviewableStatus from "discourse/helpers/reviewable-status";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class ReviewableScore extends Component {
  @gt("rs.status", 0) showStatus;

  @discourseComputed("rs.score_type.title", "reviewable.target_created_by")
  title(title, targetCreatedBy) {
    if (title && targetCreatedBy) {
      return title.replace(
        /{{username}}|%{username}/,
        targetCreatedBy.username
      );
    }

    return title;
  }

  <template>
    <tr class="reviewable-score">
      <td class="user">
        <UserLink @user={{this.rs.user}}>
          {{avatar this.rs.user imageSize="tiny"}}
          {{this.rs.user.username}}
        </UserLink>
      </td>

      <td>
        {{formatDate this.rs.created_at format="tiny"}}
      </td>

      <td>
        {{icon this.rs.score_type.icon}}
        {{this.title}}
      </td>

      {{#if this.showStatus}}
        <td class="reviewed-by">
          {{#if this.rs.reviewed_by}}
            <UserLink @user={{this.rs.reviewed_by}}>
              {{avatar this.rs.reviewed_by imageSize="tiny"}}
              {{this.rs.reviewed_by.username}}
            </UserLink>
          {{else}}
            &mdash;
          {{/if}}
        </td>

        <td>
          {{#if this.rs.reviewed_by}}
            {{formatDate this.rs.reviewed_at format="tiny"}}
          {{/if}}
        </td>

        <td>
          {{reviewableStatus this.rs.status this.reviewable.type}}
        </td>

      {{else}}
        <td colspan="4"></td>
      {{/if}}
    </tr>
  </template>
}
