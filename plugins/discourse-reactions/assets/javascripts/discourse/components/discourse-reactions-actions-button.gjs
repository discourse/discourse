import DiscourseReactionsActions from "./discourse-reactions-actions";

const ReactionsActionButton = <template>
  <div class="discourse-reactions-actions-button-shim">
    <DiscourseReactionsActions
      @post={{@post}}
      @showLogin={{@buttonActions.showLogin}}
    />
  </div>
</template>;

export default ReactionsActionButton;
