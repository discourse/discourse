import UserStream from "discourse/components/user-stream";
import DEmptyState from "discourse/ui-kit/d-empty-state";

export default <template>
  {{#if @controller.model.stream.noContent}}
    <DEmptyState
      @body={{@controller.model.emptyState.body}}
      @title={{@controller.model.emptyState.title}}
    />
  {{else}}
    <UserStream @stream={{@controller.model.stream}} />
  {{/if}}
</template>
