import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

<template>
  {{#if @showCategoryChooser}}
    <div class="edit-category__wrapper">
      <PluginOutlet
        @name="edit-topic-category"
        @outletArgs={{lazyHash model=@model buffered=@buffered}}
      >
        <CategoryChooser
          @value={{@buffered.category_id}}
          @onChange={{@topicCategoryChanged}}
          class="small"
        />
      </PluginOutlet>
    </div>
  {{/if}}

  {{#if @canEditTags}}
    <div class="edit-tags__wrapper">
      <PluginOutlet
        @name="edit-topic-tags"
        @outletArgs={{lazyHash model=@model buffered=@buffered}}
      >
        <MiniTagChooser
          @value={{@buffered.tags}}
          @onChange={{@topicTagsChanged}}
          @options={{hash
            filterable=true
            categoryId=@buffered.category_id
            minimum=@minimumRequiredTags
            filterPlaceholder="tagging.choose_for_topic"
            useHeaderFilter=true
          }}
        />
      </PluginOutlet>
    </div>
  {{/if}}

  <PluginOutlet
    @name="edit-topic"
    @connectorTagName="div"
    @outletArgs={{lazyHash model=@model buffered=@buffered}}
  />

  <div class="edit-controls">
    <DButton
      @action={{@onSave}}
      @icon="check"
      @ariaLabel="composer.save_edit"
      class="btn-primary submit-edit"
    />
    <DButton
      @action={{@onCancel}}
      @icon="xmark"
      @ariaLabel="composer.cancel"
      class="btn-default cancel-edit"
    />
    {{yield}}
  </div>
</template>
