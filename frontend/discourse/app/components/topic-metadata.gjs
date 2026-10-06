import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import DButton from "discourse/ui-kit/d-button";

export default <template>
  {{#if @showCategoryChooser}}
    <div class="edit-category__wrapper">
      <PluginOutlet
        @name="edit-topic-category"
        @outletArgs={{lazyHash model=@model buffered=@buffered}}
      >
        <CategoryChooser
          class="small"
          @onChange={{@topicCategoryChanged}}
          @value={{@buffered.category_id}}
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
