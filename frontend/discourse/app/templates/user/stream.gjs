import EmptyState from "discourse/components/empty-state";
import UserStream from "discourse/components/user-stream";

export default <template>
  {{#if @controller.model.stream.noContent}}
    {{#unless @controller.model.stream.loading}}
      <EmptyState
        @title={{@controller.model.emptyState.title}}
        @body={{@controller.model.emptyState.body}}
      />
    {{/unless}}
  {{/if}}

  <UserStream @stream={{@controller.model.stream}} />
</template>
