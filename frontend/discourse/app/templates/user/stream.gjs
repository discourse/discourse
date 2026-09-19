import UserStream from "discourse/components/user-stream";
import DEmptyState from "discourse/ui-kit/d-empty-state";

export default <template>
  {{#if @controller.model.stream.noContent}}
    {{#unless @controller.model.stream.loading}}
      <DEmptyState
        @body={{@controller.model.emptyState.body}}
        @title={{@controller.model.emptyState.title}}
      />
    {{/unless}}
  {{/if}}

  <UserStream @stream={{@controller.model.stream}} />
</template>
