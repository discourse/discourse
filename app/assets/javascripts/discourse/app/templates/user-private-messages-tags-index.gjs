import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import TagList from "discourse/components/tag-list";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="list-controls">
      <div class="container">
        <h2>{{i18n "tagging.tags"}}</h2>
      </div>
    </div>

    <div class="tag-sort-options">
      {{i18n "tagging.sort_by"}}
      <span class="tag-sort-count {{if @controller.sortedByCount 'active'}}">
        <a href {{on "click" @controller.sortByCount}}>
          {{i18n "tagging.sort_by_count"}}
        </a>
      </span>
      <span class="tag-sort-name {{if @controller.sortedByName 'active'}}">
        <a href {{on "click" @controller.sortById}}>
          {{i18n "tagging.sort_by_name"}}
        </a>
      </span>
    </div>

    <hr />

    {{#if @controller.model}}
      <TagList
        @tags={{@controller.model}}
        @sortProperties={{@controller.sortProperties}}
        @titleKey="tagging.all_tags"
        @isPrivateMessage={{true}}
        @tagsForUser={{@controller.tagsForUser}}
      />
    {{/if}}
  </template>
);
