import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DButton from "discourse/components/d-button";
import DiscourseBanner from "discourse/components/discourse-banner";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import PluginOutlet from "discourse/components/plugin-outlet";
import TagList from "discourse/components/tag-list";
import discourseTags from "discourse/helpers/discourse-tags";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import { not, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="container">
    <DiscourseBanner />
  </div>

  <div class="container tags-index">

    {{#if @controller.bulkCreateResults}}
      <div class="bulk-create-results alert alert-info">
        <DButton
          @action={{@controller.dismissResults}}
          @icon="xmark"
          class="btn-flat close"
        />

        {{#if @controller.bulkCreateResults.created.length}}
          <div class="result-section">
            <h4>
              {{i18n
                "tagging.bulk_create_success"
                count=@controller.bulkCreateResults.created.length
              }}
            </h4>
            {{discourseTags null tags=@controller.bulkCreateResults.created}}
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
            {{discourseTags null tags=@controller.bulkCreateResults.existing}}
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
        <@controller.TagsAdminDropdownComponent />
        <form
          class="bulk-create-tags-form"
          {{on "submit" @controller.bulkCreateTags}}
        >
          <label for="bulk-tags-input" class="sr-only">
            {{i18n "tagging.bulk_create_inline_placeholder"}}
          </label>
          <ExpandingTextArea
            {{on "input" (withEventValue (fn (mut @controller.bulkTagInput)))}}
            value={{@controller.bulkTagInput}}
            placeholder={{i18n "tagging.bulk_create_inline_placeholder"}}
            disabled={{@controller.isCreatingTags}}
            rows="1"
            id="bulk-tags-input"
            class="bulk-tags-input"
          />
          <DButton
            @action={{@controller.bulkCreateTags}}
            @disabled={{or
              @controller.isCreatingTags
              (not @controller.canCreateTags)
            }}
            @icon="check"
            class="btn-primary"
          />
        </form>
      {{/if}}
    </div>

    <div>
      <PluginOutlet
        @name="tags-below-title"
        @connectorTagName="div"
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
          {{on "click" @controller.sortById}}
        >{{i18n "tagging.sort_by_name"}}</a></span>
    </div>

    <hr />

    <div class="all-tag-lists">
      {{#each @controller.model.extras.categories as |category|}}
        <TagList
          @tags={{category.tags}}
          @sortProperties={{@controller.sortProperties}}
          @categoryId={{category.id}}
        />
      {{/each}}

      {{#each @controller.model.extras.tag_groups as |tagGroup|}}
        <TagList
          @tags={{tagGroup.tags}}
          @sortProperties={{@controller.sortProperties}}
          @tagGroupName={{tagGroup.name}}
        />
      {{/each}}

      {{#if @controller.model.content}}
        <TagList
          @tags={{@controller.model.content}}
          @sortProperties={{@controller.sortProperties}}
          @titleKey={{@controller.otherTagsTitleKey}}
        />
      {{/if}}
    </div>

  </div>
</template>
