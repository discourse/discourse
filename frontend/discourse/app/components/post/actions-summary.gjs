import UserAvatar from "discourse/ui-kit/d-user-avatar";
import formatDate from "discourse/ui-kit/helpers/d-format-date";
import icon from "discourse/ui-kit/helpers/d-icon";

const PostActionsSummary = <template>
  {{#each @post.actionsSummary key="id" as |actionSummary|}}
    <div class="post-action">{{actionSummary.description}}</div>
    <div class="clearfix"></div>
  {{/each}}
  {{#if @post.deletedAt}}
    <div class="post-action deleted-post">
      {{icon "trash-can"}}
      <UserAvatar @size="tiny" @user={{@post.deletedBy}} />
      {{formatDate @post.deletedAt format="tiny"}}
    </div>
  {{/if}}
</template>;

export default PostActionsSummary;
