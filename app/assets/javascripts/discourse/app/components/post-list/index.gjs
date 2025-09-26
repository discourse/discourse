/**
 * A component that renders a list of posts
 *
 * @component PostList
 *
 * @args {Array<Object>} posts - The array of post objects to display
 * @args {Function} fetchMorePosts - A function that fetches more posts. Must return a Promise that resolves to an array of new posts.
 * @args {String} emptyText (optional) - Custom text to display when there are no posts
 * @args {String|Array} additionalItemClasses (optional) - Additional classes to add to each post list item
 * @args {String} titleAriaLabel (optional) - Custom Aria label for the post title
 * @args {String} showUserInfo (optional) - Whether to show user info in the post list items
 * @args {String} idPath (optional) - The path to the key in the post object that contains the post ID
 * @args {String} urlPath (optional) - The path to the key in the post object that contains the post URL
 * @args {String} titlePath (optional) - The path to the key in the post object that contains the post title
 * @args {String} usernamePath (optional) - The path to the key in the post object that contains the post author's username
 * @args {Boolean} bulkSelectEnabled (optional) - Whether to enable bulk selection functionality
 * @args {PostBulkSelectHelper} bulkSelectHelper (optional) - Helper for managing bulk selection state
 * @args {Array} bulkActions (optional) - Array of bulk action objects for the bulk controls
 *
 * @template Usage Example:
 * ```
 * <PostList
 *    @posts={{this.posts}}
 *    @titlePath="topic_html_title"
 *    @fetchMorePosts={{this.loadMorePosts}}
 *    @emptyText={{i18n "custom_identifier.empty"}}
 *    @additionalItemClasses="custom-class"
 *    @bulkSelectEnabled={{true}}
 *    @bulkSelectHelper={{this.bulkSelectHelper}}
 *    @bulkActions={{this.bulkActions}}
 * />
 * ```
 */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import PostListBulkControls from "discourse/components/post-list/bulk-controls";
import PostListItem from "discourse/components/post-list/item";
import concatClass from "discourse/helpers/concat-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class PostList extends Component {
  @tracked loading = false;
  @tracked canLoadMore = true;
  @tracked emptyText = this.args.emptyText || i18n("post_list.empty");

  @action
  async loadMore() {
    if (
      !this.canLoadMore ||
      this.loading ||
      this.args.fetchMorePosts === undefined
    ) {
      return;
    }
    this.loading = true;

    try {
      const newPosts = await this.args.fetchMorePosts();
      this.args.posts?.addObjects(newPosts);

      if (newPosts.length === 0) {
        this.canLoadMore = false;
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    {{#if this.canLoadMore}}
      {{hideApplicationFooter}}
    {{/if}}

    <LoadMore @action={{this.loadMore}}>
      {{#if @bulkSelectEnabled}}
        {{#if @bulkSelectHelper.hasSelection}}
          <PostListBulkControls
            @bulkSelectHelper={{@bulkSelectHelper}}
            @bulkActions={{@bulkActions}}
          />
        {{/if}}
      {{/if}}

      <div
        class={{concatClass
          "post-list"
          (if @bulkSelectEnabled "post-list--bulk-select")
        }}
        ...attributes
      >
        {{#each @posts as |post|}}
          <PostListItem
            @post={{post}}
            @idPath={{@idPath}}
            @urlPath={{@urlPath}}
            @titlePath={{@titlePath}}
            @usernamePath={{@usernamePath}}
            @additionalItemClasses={{@additionalItemClasses}}
            @titleAriaLabel={{@titleAriaLabel}}
            @showUserInfo={{@showUserInfo}}
            @resumeDraft={{@resumeDraft}}
            @removeDraft={{@removeDraft}}
            @bulkSelectEnabled={{@bulkSelectEnabled}}
            @bulkSelectHelper={{@bulkSelectHelper}}
          >
            <:abovePostItemHeader>
              {{yield post to="abovePostItemHeader"}}
            </:abovePostItemHeader>
            <:belowPostItemMetaData>
              {{yield post to="belowPostItemMetaData"}}
            </:belowPostItemMetaData>
            <:abovePostItemExcerpt>
              {{yield post to="abovePostItemExcerpt"}}
            </:abovePostItemExcerpt>
            <:belowPostItem>
              {{yield post to="belowPostItem"}}
            </:belowPostItem>
          </PostListItem>
        {{else}}
          <div class="post-list__empty-text">{{this.emptyText}}</div>
        {{/each}}
      </div>
      <ConditionalLoadingSpinner @condition={{this.loading}} />
    </LoadMore>
  </template>
}
