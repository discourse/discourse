/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import LegacyReviewableUser from "../reviewable-user";

export default class ReviewableUser extends Component {
  <template>
    <div class="review-item__meta-content">
      <LegacyReviewableUser @reviewable={{@reviewable}}>
        {{yield}}
      </LegacyReviewableUser>
    </div>
  </template>
}
