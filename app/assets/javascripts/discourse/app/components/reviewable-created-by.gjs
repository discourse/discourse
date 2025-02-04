import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";

const ReviewableCreatedBy = <template>
  <div class="created-by">
    {{#if @user}}
      <UserLink @user={{@user}}>{{avatar @user imageSize="large"}}</UserLink>
    {{else}}
      {{icon "trash-can" class="deleted-user-avatar"}}
    {{/if}}
  </div>
</template>;

export default ReviewableCreatedBy;
