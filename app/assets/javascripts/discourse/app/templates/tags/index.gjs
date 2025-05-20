import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import DiscourseBanner from "discourse/components/discourse-banner";
import PluginOutlet from "discourse/components/plugin-outlet";
import TagList from "discourse/components/tag-list";
import TagsAdminDropdown from "discourse/components/tags-admin-dropdown";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="container">
      <DiscourseBanner />
    </div>

    <div class="container tags-index">

      <div class="container tags-controls">
        {{#if @controller.canAdminTags}}
          <TagsAdminDropdown @actionsMapping={{@controller.actionsMapping}} />
        {{/if}}
        <h2>{{i18n "tagging.tags"}}</h2>
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
        <span
          class="tag-sort-count {{if @controller.sortedByCount 'active'}}"
        ><a href {{on "click" @controller.sortByCount}}>{{i18n
              "tagging.sort_by_count"
            }}</a></span>
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

        {{#if @controller.model}}
          <TagList
            @tags={{@controller.model}}
            @sortProperties={{@controller.sortProperties}}
            @titleKey={{@controller.otherTagsTitleKey}}
          />
        {{/if}}
      </div>

    </div>
  </template>
);
