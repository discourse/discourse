import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";

const ReviewableCreatedBy = <template>
  <div class="created-by">
    {{#if @user}}
      <UserLink @user={{@user}}>{{avatar @user imageSize="small"}}</UserLink>
      <ReviewableCreatedByName @user={{@user}} />
    {{else}}
      {{icon "trash-can" class="deleted-user-avatar"}}
    {{/if}}
  </div>
</template>;

export default ReviewableCreatedBy;
