import { Input } from "@ember/component";
import BookmarkList from "discourse/components/bookmark-list";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "user-activity-bookmarks-page"}}

  <DConditionalLoadingSpinner @condition={{@controller.loading}}>
    <PluginOutlet @connectorTagName="div" @name="above-user-bookmarks" />

    {{#if @controller.permissionDenied}}
      <div class="alert alert-info">{{i18n
          "bookmarks.list_permission_denied"
        }}</div>
    {{else if @controller.userDoesNotHaveBookmarks}}
      <DEmptyState
        @body={{@controller.emptyStateBody}}
        @title={{i18n "user.no_bookmarks_title"}}
      />
    {{else}}
      <div class="inline-form full-width bookmark-search-form">
        <Input
          autocomplete="off"
          id="bookmark-search"
          placeholder={{i18n "bookmarks.search_placeholder"}}
          @enter={{@controller.search}}
          @type="text"
          @value={{@controller.searchTerm}}
        />
        <DButton
          class="btn-primary"
          @action={{@controller.search}}
          @icon="magnifying-glass"
        />
      </div>
      {{#if @controller.nothingFound}}
        <div class="alert alert-info">{{i18n "user.no_bookmarks_search"}}</div>
      {{else}}
        <BookmarkList
          @bulkSelectHelper={{@controller.bulkSelectHelper}}
          @content={{@controller.model.bookmarks}}
          @loadingMore={{@controller.loadingMore}}
          @loadMore={{@controller.loadMore}}
          @reload={{@controller.reload}}
        />
      {{/if}}
    {{/if}}
  </DConditionalLoadingSpinner>
</template>
