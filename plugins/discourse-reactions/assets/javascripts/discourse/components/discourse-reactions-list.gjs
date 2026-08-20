import DiscourseReactionsListEmoji from "./discourse-reactions-list-emoji";

const DiscourseReactionsList = <template>
  <span class="discourse-reactions-list" ...attributes>
    {{#if @post.reaction_users_count}}
      <span class="reactions">
        {{#each @post.reactions as |reaction|}}
          <DiscourseReactionsListEmoji @reaction={{reaction}} @post={{@post}} />
        {{/each}}
      </span>
    {{/if}}
  </span>
</template>;

export default DiscourseReactionsList;
