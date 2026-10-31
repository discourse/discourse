import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import DButton from "discourse/ui-kit/d-button";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import { i18n } from "discourse-i18n";

export default class TopicMetadata extends Component {
  @service siteSettings;

  <template>
    {{#if @showCategoryChooser}}
      <div class="edit-category__wrapper">
        <PluginOutlet
          @name="edit-topic-category"
          @outletArgs={{lazyHash model=@model buffered=@buffered}}
        >
          {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectCategory
              class="category-chooser small"
              @emit="ids"
              @identifier="topic-edit-category"
              @instanceContext={{hash topic=@model buffered=@buffered}}
              @onChange={{@topicCategoryChanged}}
              @permission="create"
              @value={{@buffered.category_id}}
            />
          {{else}}
            <CategoryChooser
              class="small"
              @onChange={{@topicCategoryChanged}}
              @value={{@buffered.category_id}}
            />
          {{/if}}
        </PluginOutlet>
      </div>
    {{/if}}

    {{#if @canEditTags}}
      <div class="edit-tags__wrapper">
        <PluginOutlet
          @name="edit-topic-tags"
          @outletArgs={{lazyHash model=@model buffered=@buffered}}
        >
          {{#if this.siteSettings.enable_new_select_controls}}
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
            <DSelectTag
              @allowCreate={{true}}
              @categoryId={{@buffered.category_id}}
              @identifier="topic-edit-tags"
              @instanceContext={{hash topic=@model buffered=@buffered}}
              @legacyKind="mini-tag-chooser"
              @minimum={{@minimumRequiredTags}}
              @multiple={{true}}
              @onChange={{@topicTagsChanged}}
              @suggestRecent={{true}}
              @texts={{hash placeholder=(i18n "tagging.choose_for_topic")}}
              @value={{@buffered.tags}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
            <MiniTagChooser
              @onChange={{@topicTagsChanged}}
              @options={{hash
                filterable=true
                categoryId=@buffered.category_id
                minimum=@minimumRequiredTags
                filterPlaceholder="tagging.choose_for_topic"
                useHeaderFilter=true
                prioritizeRecentTags=true
              }}
              @value={{@buffered.tags}}
            />
          {{/if}}
        </PluginOutlet>
      </div>
    {{/if}}

    <PluginOutlet
      @connectorTagName="div"
      @name="edit-topic"
      @outletArgs={{lazyHash model=@model buffered=@buffered}}
    />

    <div class="edit-controls">
      <DButton
        class="btn-primary submit-edit"
        @action={{@onSave}}
        @ariaLabel="composer.save_edit"
        @icon="check"
      />
      <DButton
        class="btn-default cancel-edit"
        @action={{@onCancel}}
        @ariaLabel="composer.cancel"
        @icon="xmark"
      />
      {{yield}}
    </div>
  </template>
}
