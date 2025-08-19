import UserAvatar from "discourse/components/user-avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";

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
