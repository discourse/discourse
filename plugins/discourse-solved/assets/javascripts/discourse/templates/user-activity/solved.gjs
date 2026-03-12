import UserStream from "discourse/components/user-stream";
import EmptyState from "discourse/ui-kit/d-empty-state";

export default <template>
  {{#if @controller.model.stream.noContent}}
    <EmptyState
      @title={{@controller.model.emptyState.title}}
      @body={{@controller.model.emptyState.body}}
    />
  {{else}}
    <UserStream @stream={{@controller.model.stream}} />
  {{/if}}
</template>
