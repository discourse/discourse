/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import LegacyReviewableUser from "../reviewable-user";

@tagName("")
export default class ReviewableUser extends Component {
  <template>
    <div class="review-item__meta-content" ...attributes>
      <LegacyReviewableUser @reviewable={{@reviewable}}>
        {{yield}}
      </LegacyReviewableUser>
    </div>
  </template>
}
