import RouteTemplate from "ember-route-template";
import EmptyState from "discourse/components/empty-state";
import UserStream from "discourse/components/user-stream";

export default RouteTemplate(
  <template>
    {{#if @controller.model.stream.noContent}}
      <EmptyState
        @title={{@controller.model.emptyState.title}}
        @body={{@controller.model.emptyState.body}}
      />
    {{/if}}

    <UserStream @stream={{@controller.model.stream}} />
  </template>
);
