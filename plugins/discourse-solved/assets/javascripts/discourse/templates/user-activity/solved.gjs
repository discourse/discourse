import UserStream from "discourse/components/user-stream";
import DEmptyState from "discourse/ui-kit/d-empty-state";

export default <template>
  {{#if @controller.model.stream.noContent}}
    <DEmptyState
      @title={{@controller.model.emptyState.title}}
      @body={{@controller.model.emptyState.body}}
    />
  {{else}}
    <UserStream @stream={{@controller.model.stream}} />
  {{/if}}
</template>
