import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const ReviewableCreatedBy = <template>
  <div class="created-by">
    {{#if @user}}
      <DUserLink @user={{@user}}>
        {{dAvatar @user imageSize=(if @avatarSize @avatarSize "large")}}
        {{#if @showUsername}}
          <span class="username">{{@user.username}}</span>
        {{/if}}
      </DUserLink>
    {{else}}
      {{dIcon "trash-can" class="deleted-user-avatar"}}
    {{/if}}
  </div>
</template>;

export default ReviewableCreatedBy;
