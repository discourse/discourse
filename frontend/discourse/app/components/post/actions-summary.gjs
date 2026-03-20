import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const PostActionsSummary = <template>
  {{#each @post.actionsSummary key="id" as |actionSummary|}}
    <div class="post-action">{{actionSummary.description}}</div>
    <div class="clearfix"></div>
  {{/each}}
  {{#if @post.deletedAt}}
    <div class="post-action deleted-post">
      {{dIcon "trash-can"}}
      <DUserAvatar @size="tiny" @user={{@post.deletedBy}} />
      {{dFormatDate @post.deletedAt format="tiny"}}
    </div>
  {{/if}}
</template>;

export default PostActionsSummary;
