import avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";

const PostActionsSummary = <template>
  {{#each @post.actionsSummary key="id" as |actionSummary|}}
    <div class="post-action">{{actionSummary.description}}</div>
    <div class="clearfix"></div>
  {{/each}}
  {{#if @post.deleted_at}}
    <div class="post-action deleted-post">
      {{icon "trash-can"}}
      <a
        class="trigger-user-card"
        post-user-card={{@post.deletedByUsername}}
        title={{@post.deletedByUsername}}
        aria-hidden="true"
      >
        {{avatar
          @post.deletedByAvatarTemplate
          "tiny"
          title=@post.deletedByUsername
        }}
      </a>
      {{formatDate @post.deleted_at format="tiny"}}
    </div>
  {{/if}}
</template>;

export default PostActionsSummary;
