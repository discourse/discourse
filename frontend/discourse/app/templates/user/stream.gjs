import UserStream from "discourse/components/user-stream";
import DEmptyState from "discourse/ui-kit/d-empty-state";

export default <template>
  {{#if @controller.model.stream.noContent}}
    {{#unless @controller.model.stream.loading}}
      <DEmptyState
        @title={{@controller.model.emptyState.title}}
        @body={{@controller.model.emptyState.body}}
      />
    {{/unless}}
  {{/if}}

  <UserStream @stream={{@controller.model.stream}} />
</template>
