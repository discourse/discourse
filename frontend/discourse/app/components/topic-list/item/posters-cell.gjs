import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

const PostersCell = <template>
  <td class="posters topic-list-data">
    {{#each @topic.featuredUsers as |poster|}}
      {{#if poster.moreCount}}
        <a class="posters-more-count">{{poster.moreCount}}</a>
      {{else}}
        <DUserLink
          class={{poster.extraClasses}}
          @href={{poster.user.path}}
          @username={{poster.user.username}}
        >
          {{dAvatar
            poster
            avatarTemplatePath="user.avatar_template"
            usernamePath="user.username"
            namePath="user.name"
            imageSize="small"
          }}</DUserLink>
      {{/if}}
    {{/each}}
  </td>
</template>;

export default PostersCell;
