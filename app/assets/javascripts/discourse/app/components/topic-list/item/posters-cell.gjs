import avatar from "discourse/helpers/avatar";

const PostersCell = <template>
  <td class="posters topic-list-data">
    {{#each @topic.featuredUsers as |poster|}}
      {{#if poster.moreCount}}
        <a class="posters-more-count">{{poster.moreCount}}</a>
      {{else}}
        <a
          href={{poster.user.path}}
          data-user-card={{poster.user.username}}
          class={{poster.extraClasses}}
        >{{avatar
            poster
            avatarTemplatePath="user.avatar_template"
            usernamePath="user.username"
            namePath="user.name"
            imageSize="small"
          }}</a>
      {{/if}}
    {{/each}}
  </td>
</template>;

export default PostersCell;
