import EmptyState from "discourse/components/empty-state";
import UserStream from "discourse/components/user-stream";

<template>
  {{#if @controller.model.stream.noContent}}
    <EmptyState
      @title={{@controller.model.emptyState.title}}
      @body={{@controller.model.emptyState.body}}
    />
  {{else}}
    <UserStream @stream={{@controller.model.stream}} />
  {{/if}}
</template>
