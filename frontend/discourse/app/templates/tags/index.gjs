import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";
import TagList from "discourse/components/tag-list";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { not, or } from "discourse/truth-helpers";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import { i18n } from "discourse-i18n";

async function loadTagsAdminDropdownComponent() {
  const module = await import("discourse/admin/components/tags-admin-dropdown");
  return module.default;
}

export default <template>
  <div class="container">
    <DiscourseBanner />
  </div>

  <div class="container tags-index">

    {{#if @controller.bulkCreateResults}}
      <div class="bulk-create-results alert alert-info">
        <DButton
          class="btn-flat close"
          @action={{@controller.dismissResults}}
          @icon="xmark"
        />

        {{#if @controller.bulkCreateResults.created.length}}
          <div class="result-section">
            <h4>
              {{i18n
                "tagging.bulk_create_success"
                count=@controller.bulkCreateResults.created.length
              }}
            </h4>
            {{dDiscourseTags null tags=@controller.bulkCreateResults.created}}
          </div>
        {{/if}}

        {{#if @controller.bulkCreateResults.existing.length}}
          <div class="result-section">
            <h4>
              {{i18n
                "tagging.bulk_create_already_exist"
                count=@controller.bulkCreateResults.existing.length
              }}
            </h4>
            {{dDiscourseTags null tags=@controller.bulkCreateResults.existing}}
          </div>
        {{/if}}

        {{#if @controller.hasFailedTags}}
          <div class="result-section --failed">
            <h4>{{i18n "tagging.bulk_create_some_failed"}}</h4>
            <ul>
              {{#each-in @controller.bulkCreateResults.failed as |tag error|}}
                <li><code>{{tag}}</code>: {{error}}</li>
              {{/each-in}}
            </ul>
          </div>
        {{/if}}
      </div>
    {{/if}}

    <div class="container tags-controls">
      <h2>{{i18n "tagging.tags"}}</h2>
      {{#if @controller.canAdminTags}}
        <DAsyncContent @asyncData={{(loadTagsAdminDropdownComponent)}}>
          <:content as |TagsAdminDropdownComponent|>
            <TagsAdminDropdownComponent />
            <form
              class="bulk-create-tags-form"
              {{on "submit" @controller.bulkCreateTags}}
            >
              <label class="sr-only" for="bulk-tags-input">
                {{i18n "tagging.bulk_create_inline_placeholder"}}
              </label>
              <DExpandingTextArea
                class="bulk-tags-input"
                disabled={{@controller.isCreatingTags}}
                id="bulk-tags-input"
                placeholder={{i18n "tagging.bulk_create_inline_placeholder"}}
                rows="1"
                @value={{@controller.bulkTagInput}}
                {{on
                  "input"
                  (withEventValue (fn (mut @controller.bulkTagInput)))
                }}
              />
              <DButton
                class="btn-primary"
                @action={{@controller.bulkCreateTags}}
                @disabled={{or
                  @controller.isCreatingTags
                  (not @controller.canCreateTags)
                }}
                @icon="tag"
                @label="tagging.bulk_create_button"
              />
            </form>
          </:content>
        </DAsyncContent>
      {{/if}}
    </div>

    <div>
      <PluginOutlet
        @connectorTagName="div"
        @name="tags-below-title"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </div>

    <div class="tag-sort-options">
      {{i18n "tagging.sort_by"}}
      <span class="tag-sort-count {{if @controller.sortedByCount 'active'}}"><a
          href
          {{on "click" @controller.sortByCount}}
        >{{i18n "tagging.sort_by_count"}}</a></span>
      <span class="tag-sort-name {{if @controller.sortedByName 'active'}}"><a
          href
          {{on "click" @controller.sortByName}}
        >{{i18n "tagging.sort_by_name"}}</a></span>
    </div>

    <hr />

    <div class="all-tag-lists">
      {{#each @controller.model.extras.categories as |category|}}
        <TagList
          @categoryId={{category.id}}
          @sortProperties={{@controller.sortProperties}}
          @tags={{category.tags}}
        />
      {{/each}}

      {{#each @controller.model.extras.tag_groups as |tagGroup|}}
        <TagList
          @sortProperties={{@controller.sortProperties}}
          @tagGroupName={{tagGroup.name}}
          @tags={{tagGroup.tags}}
        />
      {{/each}}

      {{#if @controller.model.content}}
        <TagList
          @sortProperties={{@controller.sortProperties}}
          @tags={{@controller.model.content}}
          @titleKey={{@controller.otherTagsTitleKey}}
        />
      {{/if}}
    </div>

  </div>
</template>
