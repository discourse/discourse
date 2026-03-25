import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import TopicCategory from "discourse/components/topic-category";
import TopicMetadata from "discourse/components/topic-metadata";
import TopicTitleEditor from "discourse/components/topic-title-editor";
import icon from "discourse/helpers/d-icon";

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
          {{htmlSafe @topic.fancyTitle~}}
          {{~#if @topic.details.can_edit~}}
            <span class="edit-topic__wrapper">
              {{icon "pencil" class="edit-topic"}}
            </span>
          {{~/if}}
        </a>
      </h1>
      <TopicCategory @topic={{@topic}} class="topic-category" />
    {{/if}}
  </div>
</template>
