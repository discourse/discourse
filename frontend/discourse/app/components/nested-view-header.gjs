import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicCategory from "discourse/components/topic-category";
import TopicMetadata from "discourse/components/topic-metadata";
import TopicTitleEditor from "discourse/components/topic-title-editor";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";

<template>
  <div class="nested-view__header">
    {{#if @editingTopic}}
      <div class="edit-topic-title">
        <TopicTitleEditor
          @bufferedTitle={{@buffered.title}}
          @model={{@topic}}
          @buffered={{@buffered}}
        />

        <TopicMetadata
          @buffered={{@buffered}}
          @model={{@topic}}
          @showCategoryChooser={{@showCategoryChooser}}
          @canEditTags={{@canEditTags}}
          @minimumRequiredTags={{@minimumRequiredTags}}
          @onSave={{@finishedEditingTopic}}
          @onCancel={{@cancelEditingTopic}}
          @topicCategoryChanged={{@topicCategoryChanged}}
          @topicTagsChanged={{@topicTagsChanged}}
        />
      </div>
    {{else}}
      <h1 class="nested-view__title">
        <a
          href={{@topic.url}}
          {{on "click" @startEditingTopic}}
          class="fancy-title"
        >
          {{trustHTML @topic.fancyTitle~}}
          {{~#if @topic.details.can_edit~}}
            <span class="edit-topic__wrapper">
              {{icon "pencil" class="edit-topic"}}
            </span>
          {{~/if}}
        </a>
      </h1>
      <TopicCategory @topic={{@topic}} class="topic-category" />
    {{/if}}
    <PluginOutlet
      @name="topic-title"
      @connectorTagName="div"
      @outletArgs={{lazyHash model=@topic}}
    />
  </div>
</template>
