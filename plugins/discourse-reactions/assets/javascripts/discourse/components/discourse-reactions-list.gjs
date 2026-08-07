import DiscourseReactionsListEmoji from "./discourse-reactions-list-emoji";

const DiscourseReactionsList = <template>
  <div class="discourse-reactions-list" ...attributes>
    {{#if @post.reaction_users_count}}
      <div class="reactions">
        {{#each @post.reactions as |reaction|}}
          <DiscourseReactionsListEmoji @reaction={{reaction}} @post={{@post}} />
        {{/each}}
      </div>
    {{/if}}
  </div>
</template>;

export default DiscourseReactionsList;
