export const PostMenuButtonWrapper = <template>
  <@buttonConfig.Component
    class="btn-flat"
    ...attributes
    @action={{@buttonConfig.action}}
    @actionMode={{@buttonConfig.actionMode}}
    @context={{@buttonConfig.context}}
    @post={{@post}}
    @secondaryAction={{@buttonConfig.secondaryAction}}
    @shouldRender={{@buttonConfig.shouldRender}}
    @showLabel={{@buttonConfig.showLabel}}
  />
</template>;

export default PostMenuButtonWrapper;
