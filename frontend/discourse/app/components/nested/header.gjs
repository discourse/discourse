import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicCategory from "discourse/components/topic-category";
import TopicMetadata from "discourse/components/topic-metadata";
import TopicStatus from "discourse/components/topic-status";
import TopicTitleEditor from "discourse/components/topic-title-editor";
import lazyHash from "discourse/helpers/lazy-hash";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";

export default class NestedHeader extends Component {
  @service header;

  @action
  handleIntersectionChange(event) {
    this.header.mainTopicTitleVisible =
      event.isIntersecting || event.boundingClientRect.top > 0;
  }

  @action
  handleTitleDestroy() {
    this.header.mainTopicTitleVisible = false;
  }

  <template>
    <div
      class="nested-view__header"
      {{dObserveIntersection this.handleIntersectionChange}}
      {{willDestroy this.handleTitleDestroy}}
    >
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
          <TopicStatus @topic={{@topic}} />
          <a
            href={{@topic.url}}
            {{on "click" @startEditingTopic}}
            class="fancy-title"
          >
            {{trustHTML @topic.fancyTitle~}}
            {{~#if @topic.details.can_edit~}}
              <span class="edit-topic__wrapper">
                {{dIcon "pencil" class="edit-topic"}}
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
}
