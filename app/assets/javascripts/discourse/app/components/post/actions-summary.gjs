import avatar from "discourse/helpers/bound-avatar-template";
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
      <a
        class="trigger-user-card"
        post-user-card={{@post.deletedBy.username}}
        title={{@post.deletedBy.username}}
        aria-hidden="true"
      >
        {{avatar
          @post.deletedBy.avatar_template
          "tiny"
          title=@post.deletedBy.username
        }}
      </a>
      {{formatDate @post.deletedAt format="tiny"}}
    </div>
  {{/if}}
</template>;

export default PostActionsSummary;
