import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";

const PostersCell = <template>
  <td class="posters topic-list-data">
    {{#each @topic.featuredUsers as |poster|}}
      {{#if poster.moreCount}}
        <a class="posters-more-count">{{poster.moreCount}}</a>
      {{else}}
        <UserLink
          @username={{poster.user.username}}
          @href={{poster.user.path}}
          class={{poster.extraClasses}}
        >
          {{avatar
            poster
            avatarTemplatePath="user.avatar_template"
            usernamePath="user.username"
            namePath="user.name"
            imageSize="small"
          }}</UserLink>
      {{/if}}
    {{/each}}
  </td>
</template>;

export default PostersCell;
