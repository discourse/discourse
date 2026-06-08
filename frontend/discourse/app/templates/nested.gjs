import { array } from "@ember/helper";
import Nested from "discourse/components/nested";
import PostTextSelection from "discourse/components/post-text-selection";
import SelectedPosts from "discourse/components/selected-posts";

export default <template>
  {{#each (array @controller.topic) key="id" as |topic|}}
    <PostTextSelection
      @quoteState={{@controller.quoteState}}
      @selectText={{@controller.selectText}}
      @buildQuoteMarkdown={{@controller.buildQuoteMarkdown}}
      @editPost={{@controller.editPost}}
      @topic={{topic}}
    />

    <div
      class="selected-posts nested-view__selected-posts
        {{unless @controller.multiSelect 'hidden'}}"
    >
      <SelectedPosts
        @selectedPostsCount={{@controller.selectedPostsCount}}
        @canSelectAll={{@controller.canSelectAll}}
        @canDeselectAll={{@controller.canDeselectAll}}
        @canDeleteSelected={{@controller.canDeleteSelected}}
        @canMergeTopic={{@controller.canMergeTopic}}
        @canChangeOwner={{@controller.canChangeOwner}}
        @canMergePosts={{@controller.canMergePosts}}
        @toggleMultiSelect={{@controller.toggleMultiSelect}}
        @mergePosts={{@controller.mergePosts}}
        @deleteSelected={{@controller.deleteSelected}}
        @deselectAll={{@controller.deselectAll}}
        @selectAll={{@controller.selectAll}}
      />
    </div>

    <Nested
      @topic={{topic}}
      @opPost={{@controller.opPost}}
      @rootNodes={{@controller.rootNodes}}
      @hasMoreRoots={{@controller.hasMoreRoots}}
      @loadingMore={{@controller.loadingMore}}
      @loadMoreRoots={{@controller.loadMoreRoots}}
      @sort={{@controller.sort}}
      @changeSort={{@controller.changeSort}}
      @replyToPost={{@controller.replyToPost}}
      @editPost={{@controller.editPost}}
      @deletePost={{@controller.deletePost}}
      @recoverPost={{@controller.recoverPost}}
      @showFlags={{@controller.showFlags}}
      @showHistory={{@controller.showHistory}}
      @changeNotice={{@controller.changeNotice}}
      @changePostOwner={{@controller.changePostOwner}}
      @grantBadge={{@controller.grantBadge}}
      @lockPost={{@controller.lockPost}}
      @unlockPost={{@controller.unlockPost}}
      @permanentlyDeletePost={{@controller.permanentlyDeletePost}}
      @rebakePost={{@controller.rebakePost}}
      @showPagePublish={{@controller.showPagePublish}}
      @togglePostType={{@controller.togglePostType}}
      @toggleWiki={{@controller.toggleWiki}}
      @unhidePost={{@controller.unhidePost}}
      @postNumber={{@controller.postNumber}}
      @contextMode={{@controller.contextMode}}
      @targetPostNumber={{@controller.targetPostNumber}}
      @initialFocusedPath={{@controller.initialFocusedPath}}
      @setFocusedPostNumber={{@controller.setFocusedPostNumber}}
      @saveScrollPosition={{@controller.saveScrollPosition}}
      @viewFullThread={{@controller.viewFullThread}}
      @pinnedPostIds={{@controller.pinnedPostIds}}
      @newRootPostCount={{@controller.newRootPostIds.length}}
      @loadNewRoots={{@controller.loadNewRoots}}
      @editingTopic={{@controller.editingTopic}}
      @startEditingTopic={{@controller.startEditingTopic}}
      @cancelEditingTopic={{@controller.cancelEditingTopic}}
      @finishedEditingTopic={{@controller.finishedEditingTopic}}
      @showCategoryChooser={{@controller.showCategoryChooser}}
      @canEditTags={{@controller.canEditTags}}
      @buffered={{@controller.buffered}}
      @topicCategoryChanged={{@controller.topicCategoryChanged}}
      @topicTagsChanged={{@controller.topicTagsChanged}}
      @minimumRequiredTags={{@controller.minimumRequiredTags}}
      @expansionState={{@controller.expansionState}}
      @fetchedChildrenCache={{@controller.fetchedChildrenCache}}
      @scrollAnchor={{@controller.scrollAnchor}}
      @showActivityLog={{@controller.showActivityLog}}
      @collapseReplies={{@controller.collapseReplies}}
      @multiSelect={{@controller.multiSelect}}
      @togglePostSelection={{@controller.togglePostSelection}}
      @selectReplies={{@controller.selectReplies}}
      @selectBelow={{@controller.selectBelow}}
      @postSelected={{@controller.postSelected}}
    />
  {{/each}}
</template>
