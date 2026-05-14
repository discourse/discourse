import Nested from "discourse/components/nested";
import NestedContextView from "discourse/components/nested/context-view";
import NestedTopicTimeline from "discourse/components/nested/topic-timeline";
import PostTextSelection from "discourse/components/post-text-selection";
import { and, not } from "discourse/truth-helpers";

export default <template>
  <PostTextSelection
    @quoteState={{@controller.quoteState}}
    @selectText={{@controller.selectText}}
    @buildQuoteMarkdown={{@controller.buildQuoteMarkdown}}
    @editPost={{@controller.editPost}}
    @topic={{@controller.topic}}
  />

  {{! Two-column grid matching flat's .container.posts: content on
      the left auto-sized to the post body width, timeline on the
      right auto-sized to the scrubber. With both as grid items the
      grid sizes to their combined max-content — same behavior as
      flat — rather than stretching to fill #main-outlet. }}
  <div class="nested-topic-layout">
    <div class="nested-topic-layout__content">
      {{#if @controller.contextMode}}
        <NestedContextView
          @topic={{@controller.topic}}
          @opPost={{@controller.opPost}}
          @contextChain={{@controller.contextChain}}
          @targetPostNumber={{@controller.targetPostNumber}}
          @contextNoAncestors={{@controller.contextNoAncestors}}
          @ancestorsTruncated={{@controller.ancestorsTruncated}}
          @sort={{@controller.sort}}
          @changeSort={{@controller.changeSort}}
          @viewFullThread={{@controller.viewFullThread}}
          @viewParentContext={{@controller.viewParentContext}}
          @replyToPost={{@controller.replyToPost}}
          @editPost={{@controller.editPost}}
          @deletePost={{@controller.deletePost}}
          @recoverPost={{@controller.recoverPost}}
          @showFlags={{@controller.showFlags}}
          @showHistory={{@controller.showHistory}}
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
        />
      {{else}}
        <Nested
          @topic={{@controller.topic}}
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
          @postNumber={{@controller.postNumber}}
          @pinnedPostIds={{@controller.pinnedPostIds}}
          @rootSummary={{@controller.rootSummary}}
          @jumpToRootPage={{@controller.jumpToRootPage}}
          @firstLoadedPage={{@controller.firstLoadedPage}}
          @loadPreviousRoots={{@controller.loadPreviousRoots}}
          @hasMoreRootsBefore={{@controller.hasMoreRootsBefore}}
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
        />
      {{/if}}
    </div>

    {{! Desktop-only: matches flat view, which uses topic-navigation to
        suppress the timeline on mobileView. Skipping at the render layer
        also avoids running scroll listeners / IO observers in the
        background. Context view (single-thread) has no use for a
        whole-topic scrubber. }}
    {{#if (and (not @controller.contextMode) @controller.site.desktopView)}}
      {{#if @controller.rootSummary}}
        <NestedTopicTimeline
          @summary={{@controller.rootSummary}}
          @sort={{@controller.sort}}
          @jumpToRootPage={{@controller.jumpToRootPage}}
          @firstLoadedPage={{@controller.firstLoadedPage}}
        />
      {{/if}}
    {{/if}}
  </div>
</template>
