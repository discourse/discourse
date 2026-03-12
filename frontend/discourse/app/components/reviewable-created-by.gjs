import UserLink from "discourse/ui-kit/d-user-link";
import avatar from "discourse/ui-kit/helpers/d-avatar";
import icon from "discourse/ui-kit/helpers/d-icon";

const ReviewableCreatedBy = <template>
  <div class="created-by">
    {{#if @user}}
      <UserLink @user={{@user}}>
        {{avatar @user imageSize=(if @avatarSize @avatarSize "large")}}
        {{#if @showUsername}}
          <span class="username">{{@user.username}}</span>
        {{/if}}
      </UserLink>
    {{else}}
      {{icon "trash-can" class="deleted-user-avatar"}}
    {{/if}}
  </div>
</template>;

export default ReviewableCreatedBy;
