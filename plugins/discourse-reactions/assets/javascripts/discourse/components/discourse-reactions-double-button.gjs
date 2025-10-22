const DiscourseReactionsDoubleButton = <template>
  <div class="discourse-reactions-double-button">
    {{#if @post.reaction_users_count}}
      <@counterComponent />
    {{/if}}

    {{#unless @post.yours}}
      <@buttonComponent />
    {{/unless}}
  </div>
</template>;

export default DiscourseReactionsDoubleButton;
