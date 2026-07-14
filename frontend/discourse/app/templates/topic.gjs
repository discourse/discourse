import { array, concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import AddCategoryTagClasses from "discourse/components/add-category-tag-classes";
import AddTopicStatusClasses from "discourse/components/add-topic-status-classes";
import AnonymousTopicFooterButtons from "discourse/components/anonymous-topic-footer-buttons";
import DiscourseBanner from "discourse/components/discourse-banner";
import DiscourseTopic from "discourse/components/discourse-topic";
import EmbedModeComposer from "discourse/components/embed-mode-composer";
import EmbedTopicFooter from "discourse/components/embed-topic-footer";
import MoreTopics from "discourse/components/more-topics";
import Nested from "discourse/components/nested";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostStream from "discourse/components/post-stream";
import PostTextSelection from "discourse/components/post-text-selection";
import PrivateMessageGlyph from "discourse/components/private-message-glyph";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import SelectedPosts from "discourse/components/selected-posts";
import SharedDraftControls from "discourse/components/shared-draft-controls";
import SignupCta from "discourse/components/signup-cta";
import SlowModeInfo from "discourse/components/slow-mode-info";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import TopicCategory from "discourse/components/topic-category";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";
import TopicMap from "discourse/components/topic-map/index";
import TopicMetadata from "discourse/components/topic-metadata";
import TopicNavigation from "discourse/components/topic-navigation";
import TopicProgress from "discourse/components/topic-progress";
import TopicSkipLinks from "discourse/components/topic-skip-links";
import TopicStatus from "discourse/components/topic-status";
import TopicTimeline from "discourse/components/topic-timeline";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import TopicTitle from "discourse/components/topic-title";
import TopicTitleEditor from "discourse/components/topic-title-editor";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import hideScrollableContent from "discourse/helpers/hide-scrollable-content";
import lazyHash from "discourse/helpers/lazy-hash";
import routeAction from "discourse/helpers/route-action";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DCookText from "discourse/ui-kit/d-cook-text";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import booleanString from "../helpers/boolean-string";

export default <template>
  {{#unless @controller.shouldRenderNestedView}}
    {{#let @controller.model.postStream as |postStream|}}
      {{#unless (and postStream.loaded postStream.loadedAllPosts)}}
        {{hideApplicationFooter}}
      {{/unless}}
    {{/let}}
  {{/unless}}

  <DiscourseTopic
    @multiSelect={{@controller.multiSelect}}
    @enteredAt={{@controller.enteredAt}}
    @topic={{@controller.model}}
    @hasScrolled={{@controller.hasScrolled}}
  >
    <TopicSkipLinks
      @postStream={{@controller.model.postStream}}
      @topic={{@controller.model}}
    />
    {{#if @controller.model}}
      <AddCategoryTagClasses
        @category={{@controller.model.category}}
        @tags={{@controller.model.tags}}
      />
      <AddTopicStatusClasses @topic={{@controller.model}} />
      {{bodyClass (concat "archetype-" @controller.model.archetype)}}
      {{#if @controller.shouldRenderNestedView}}
        {{#let @controller.nestedController as |nested|}}
          <PostTextSelection
            @quoteState={{nested.quoteState}}
            @selectText={{nested.selectText}}
            @buildQuoteMarkdown={{nested.buildQuoteMarkdown}}
            @editPost={{nested.editPost}}
            @topic={{@controller.model}}
          />

          <div
            class="selected-posts nested-view__selected-posts
              {{unless nested.multiSelect 'hidden'}}"
          >
            <SelectedPosts
              @selectedPostsCount={{nested.selectedPostsCount}}
              @canSelectAll={{nested.canSelectAll}}
              @canDeselectAll={{nested.canDeselectAll}}
              @canDeleteSelected={{nested.canDeleteSelected}}
              @canMergeTopic={{nested.canMergeTopic}}
              @canChangeOwner={{nested.canChangeOwner}}
              @canMergePosts={{nested.canMergePosts}}
              @toggleMultiSelect={{nested.toggleMultiSelect}}
              @mergePosts={{nested.mergePosts}}
              @deleteSelected={{nested.deleteSelected}}
              @deselectAll={{nested.deselectAll}}
              @selectAll={{nested.selectAll}}
            />
          </div>

          <Nested
            @topic={{@controller.model}}
            @opPost={{nested.opPost}}
            @rootNodes={{nested.rootNodes}}
            @hasMoreRoots={{nested.hasMoreRoots}}
            @loadingMore={{nested.loadingMore}}
            @loadMoreRoots={{nested.loadMoreRoots}}
            @sort={{nested.sort}}
            @changeSort={{nested.changeSort}}
            @replyToPost={{nested.replyToPost}}
            @editPost={{nested.editPost}}
            @deletePost={{nested.deletePost}}
            @recoverPost={{nested.recoverPost}}
            @showFlags={{nested.showFlags}}
            @showHistory={{nested.showHistory}}
            @changeNotice={{nested.changeNotice}}
            @changePostOwner={{nested.changePostOwner}}
            @grantBadge={{nested.grantBadge}}
            @lockPost={{nested.lockPost}}
            @unlockPost={{nested.unlockPost}}
            @permanentlyDeletePost={{nested.permanentlyDeletePost}}
            @rebakePost={{nested.rebakePost}}
            @showPagePublish={{nested.showPagePublish}}
            @togglePostType={{nested.togglePostType}}
            @toggleWiki={{nested.toggleWiki}}
            @unhidePost={{nested.unhidePost}}
            @postNumber={{nested.postNumber}}
            @contextMode={{nested.contextMode}}
            @contextNoAncestors={{nested.contextNoAncestors}}
            @ancestorsTruncated={{nested.ancestorsTruncated}}
            @targetPostNumber={{nested.targetPostNumber}}
            @initialFocusedPath={{nested.initialFocusedPath}}
            @setFocusedPostNumber={{nested.setFocusedPostNumber}}
            @saveScrollPosition={{nested.saveScrollPosition}}
            @viewFullThread={{nested.viewFullThread}}
            @viewParentContext={{nested.viewParentContext}}
            @pinnedPostIds={{nested.pinnedPostIds}}
            @newRootPostCount={{nested.newRootPostCount}}
            @loadNewRoots={{nested.loadNewRoots}}
            @editingTopic={{nested.editingTopic}}
            @startEditingTopic={{nested.startEditingTopic}}
            @cancelEditingTopic={{nested.cancelEditingTopic}}
            @finishedEditingTopic={{nested.finishedEditingTopic}}
            @showCategoryChooser={{nested.showCategoryChooser}}
            @canEditTags={{nested.canEditTags}}
            @buffered={{nested.buffered}}
            @topicCategoryChanged={{nested.topicCategoryChanged}}
            @topicTagsChanged={{nested.topicTagsChanged}}
            @minimumRequiredTags={{nested.minimumRequiredTags}}
            @expansionState={{nested.expansionState}}
            @fetchedChildrenCache={{nested.fetchedChildrenCache}}
            @scrollAnchor={{nested.scrollAnchor}}
            @clearScrollAnchor={{nested.clearScrollAnchor}}
            @showActivityLog={{nested.showActivityLog}}
            @collapseReplies={{nested.collapseReplies}}
            @multiSelect={{nested.multiSelect}}
            @togglePostSelection={{nested.togglePostSelection}}
            @selectReplies={{nested.selectReplies}}
            @selectBelow={{nested.selectBelow}}
            @postSelected={{nested.postSelected}}
          />
        {{/let}}
      {{else}}

        {{#unless @controller.shouldHideScrollableContentAbove}}
          <div class="container">
            <DiscourseBanner
              @overlay={{@controller.hasScrolled}}
              @hide={{@controller.model.errorLoading}}
            />
          </div>
        {{/unless}}

        {{#unless @controller.shouldHideScrollableContentAbove}}
          {{#if @controller.showSharedDraftControls}}
            <SharedDraftControls @topic={{@controller.model}} />
          {{/if}}

          <span>
            <PluginOutlet
              @name="topic-above-post-stream"
              @connectorTagName="div"
              @outletArgs={{lazyHash
                model=@controller.model
                editFirstPost=@controller.editFirstPost
              }}
            />
          </span>
        {{/unless}}

        {{#if @controller.model.postStream.loaded}}
          {{#if @controller.model.postStream.firstPostPresent}}
            <TopicTitle
              @cancelled={{@controller.cancelEditingTopic}}
              @save={{@controller.finishedEditingTopic}}
              @model={{@controller.model}}
            >
              {{#if @controller.editingTopic}}
                <div class="edit-topic-title">
                  <PrivateMessageGlyph
                    @shouldShow={{@controller.model.isPrivateMessage}}
                  />

                  <TopicTitleEditor
                    @isEditingLocalization={{@controller.editingTopicLocalization}}
                    @translationTitle={{@controller.translationTitle}}
                    @translationLocale={{@controller.translationLocale}}
                    @bufferedTitle={{@controller.buffered.title}}
                    @model={{@controller.model}}
                    @buffered={{@controller.buffered}}
                  />

                  <TopicMetadata
                    @buffered={{@controller.buffered}}
                    @model={{@controller.model}}
                    @showCategoryChooser={{@controller.showCategoryChooser}}
                    @canEditTags={{@controller.canEditTags}}
                    @minimumRequiredTags={{@controller.minimumRequiredTags}}
                    @onSave={{@controller.finishedEditingTopic}}
                    @onCancel={{@controller.cancelEditingTopic}}
                    @topicCategoryChanged={{@controller.topicCategoryChanged}}
                    @topicTagsChanged={{@controller.topicTagsChanged}}
                  >
                    {{#if @controller.canRemoveTopicFeaturedLink}}
                      <a
                        href
                        {{on "click" @controller.removeFeaturedLink}}
                        class="remove-featured-link"
                        title={{i18n "composer.remove_featured_link"}}
                      >
                        {{dIcon "circle-xmark"}}
                        {{@controller.featuredLinkDomain}}
                      </a>
                    {{/if}}
                  </TopicMetadata>
                </div>

              {{else}}
                <h1
                  data-topic-id={{@controller.model.id}}
                  {{! Prevent duplicating the topic title heading on screen readers when the header is displaying the title
                in the header }}
                  aria-hidden={{booleanString
                    @controller.titleIsVisibleOnHeader
                  }}
                >
                  {{#unless @controller.model.is_warning}}
                    {{#if @controller.canSendPms}}
                      <PrivateMessageGlyph
                        @shouldShow={{@controller.model.isPrivateMessage}}
                        @href={{@controller.pmPath}}
                        @title="topic_statuses.personal_message.title"
                        @ariaLabel="user.messages.inbox"
                      />
                    {{else}}
                      <PrivateMessageGlyph
                        @shouldShow={{@controller.model.isPrivateMessage}}
                      />
                    {{/if}}
                  {{/unless}}

                  {{#if @controller.model.details.loaded}}
                    <TopicStatus @topic={{@controller.model}} />
                    <a
                      href={{@controller.model.url}}
                      {{on "click" @controller.handleTitleClick}}
                      class="fancy-title"
                    >
                      {{trustHTML @controller.model.fancyTitle~}}
                      {{~#if @controller.model.details.can_edit~}}
                        <span class="edit-topic__wrapper">
                          {{dIcon "pencil" class="edit-topic"}}
                        </span>
                      {{~/if}}
                    </a>
                  {{/if}}

                  <PluginOutlet
                    @name="topic-title-suffix"
                    @outletArgs={{lazyHash model=@controller.model}}
                  />
                </h1>

                <PluginOutlet
                  @name="topic-category-wrapper"
                  @outletArgs={{lazyHash topic=@controller.model}}
                >
                  <TopicCategory
                    @topic={{@controller.model}}
                    class="topic-category"
                  />
                </PluginOutlet>

              {{/if}}
            </TopicTitle>

            {{#if @controller.model.publishedPage}}
              <div class="published-page-notice">
                <div class="details">
                  {{#if @controller.model.publishedPage.public}}
                    <span class="is-public">{{i18n
                        "topic.publish_page.public"
                      }}</span>
                  {{/if}}
                  {{i18n "topic.publish_page.topic_published"}}
                  <div>
                    <a
                      href={{@controller.model.publishedPage.url}}
                      target="_blank"
                      rel="noopener noreferrer"
                    >{{@controller.model.publishedPage.url}}</a>
                  </div>
                </div>
                <div class="controls">
                  <DButton
                    @icon="file"
                    @label="topic.publish_page.publishing_settings"
                    @action={{routeAction "showPagePublish"}}
                  />
                </div>
              </div>
            {{/if}}

          {{/if}}

          <div class="container posts">
            <div
              class="selected-posts {{unless @controller.multiSelect 'hidden'}}"
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

            {{#if
              (and @controller.showBottomTopicMap @controller.loadedAllPosts)
            }}
              <div class="topic-map --bottom">
                <TopicMap
                  @model={{@controller.model}}
                  @topicDetails={{@controller.model.details}}
                  @postStream={{@controller.model.postStream}}
                  @showPMMap={{eq
                    @controller.model.archetype
                    "private_message"
                  }}
                  @showInvite={{routeAction "showInvite"}}
                  @removeAllowedGroup={{@controller.removeAllowedGroup}}
                  @removeAllowedUser={{@controller.removeAllowedUser}}
                />
              </div>
            {{/if}}

            <PluginOutlet @name="above-timeline" @connectorTagName="div" />

            <TopicNavigation
              @topic={{@controller.model}}
              @jumpToDate={{@controller.jumpToDate}}
              @jumpToIndex={{@controller.jumpToIndex}}
              class="topic-navigation"
              as |info toggleProgressExpansion|
            >
              <PluginOutlet
                @name="topic-navigation"
                @connectorTagName="div"
                @outletArgs={{lazyHash
                  topic=@controller.model
                  renderTimeline=info.renderTimeline
                  topicProgressExpanded=info.topicProgressExpanded
                }}
              />

              {{#if info.renderTimeline}}
                <TopicTimeline
                  @info={{info}}
                  @model={{@controller.model}}
                  @replyToPost={{@controller.replyToPost}}
                  @showTopReplies={{@controller.showTopReplies}}
                  @jumpToPostPrompt={{@controller.jumpToPostPrompt}}
                  @enteredIndex={{@controller.enteredIndex}}
                  @prevEvent={{info.prevEvent}}
                  @jumpTop={{@controller.jumpTop}}
                  @jumpBottom={{@controller.jumpBottom}}
                  @jumpEnd={{@controller.jumpEnd}}
                  @jumpToIndex={{@controller.jumpToIndex}}
                  @toggleMultiSelect={{@controller.toggleMultiSelect}}
                  @showTopicSlowModeUpdate={{routeAction
                    "showTopicSlowModeUpdate"
                  }}
                  @deleteTopic={{@controller.deleteTopic}}
                  @recoverTopic={{@controller.recoverTopic}}
                  @toggleClosed={{@controller.toggleClosed}}
                  @toggleArchived={{@controller.toggleArchived}}
                  @toggleVisibility={{@controller.toggleVisibility}}
                  @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                  @showFeatureTopic={{routeAction "showFeatureTopic"}}
                  @showChangeTimestamp={{routeAction "showChangeTimestamp"}}
                  @resetBumpDate={{@controller.resetBumpDate}}
                  @convertToPublicTopic={{@controller.convertToPublicTopic}}
                  @convertToPrivateMessage={{@controller.convertToPrivateMessage}}
                  @fullscreen={{info.topicProgressExpanded}}
                />
              {{else}}
                <TopicProgress
                  @prevEvent={{info.prevEvent}}
                  @topic={{@controller.model}}
                  @onExpandToggle={{toggleProgressExpansion}}
                  @jumpToPost={{@controller.jumpToPost}}
                >
                  <PluginOutlet
                    @name="before-topic-progress"
                    @connectorTagName="div"
                    @outletArgs={{lazyHash
                      model=@controller.model
                      jumpToPost=@controller.jumpToPost
                    }}
                  />
                  <TopicAdminMenu
                    @topic={{@controller.model}}
                    @toggleMultiSelect={{@controller.toggleMultiSelect}}
                    @showTopicSlowModeUpdate={{routeAction
                      "showTopicSlowModeUpdate"
                    }}
                    @deleteTopic={{@controller.deleteTopic}}
                    @recoverTopic={{@controller.recoverTopic}}
                    @toggleClosed={{@controller.toggleClosed}}
                    @toggleArchived={{@controller.toggleArchived}}
                    @toggleVisibility={{@controller.toggleVisibility}}
                    @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                    @showFeatureTopic={{routeAction "showFeatureTopic"}}
                    @showChangeTimestamp={{routeAction "showChangeTimestamp"}}
                    @resetBumpDate={{@controller.resetBumpDate}}
                    @convertToPublicTopic={{@controller.convertToPublicTopic}}
                    @convertToPrivateMessage={{@controller.convertToPrivateMessage}}
                  />
                </TopicProgress>
              {{/if}}

              <PluginOutlet
                @name="topic-navigation-bottom"
                @connectorTagName="div"
                @outletArgs={{lazyHash model=@controller.model}}
              />
            </TopicNavigation>

            <div class="row">
              <section
                class="topic-area"
                id="topic"
                data-topic-id={{@controller.model.id}}
              >
                <div class="posts-wrapper">
                  <span>
                    <PluginOutlet
                      @name="topic-above-posts"
                      @connectorTagName="div"
                      @outletArgs={{lazyHash model=@controller.model}}
                    />
                  </span>

                  {{#if @controller.model.postStream.firstPostNotLoaded}}
                    {{hideScrollableContent "above"}}
                  {{/if}}

                  {{#unless @controller.model.postStream.loadingFilter}}
                    <PostStream
                      @postStream={{@controller.model.postStream}}
                      @canCreatePost={{@controller.model.details.can_create_post}}
                      @multiSelect={{@controller.multiSelect}}
                      @selectedPostsCount={{@controller.selectedPostsCount}}
                      @filteredPostsCount={{@controller.model.postStream.filteredPostsCount}}
                      @selectedQuery={{@controller.selectedQuery}}
                      @gaps={{@controller.model.postStream.gaps}}
                      @showReadIndicator={{@controller.model.show_read_indicator}}
                      @streamFilters={{@controller.model.postStream.streamFilters}}
                      @lastReadPostNumber={{@controller.userLastReadPostNumber}}
                      @highestPostNumber={{@controller.highestPostNumber}}
                      @showFlags={{@controller.showPostFlags}}
                      @editPost={{@controller.editPost}}
                      @showHistory={{routeAction "showHistory"}}
                      @showLogin={{routeAction "showLogin"}}
                      @showRawEmail={{routeAction "showRawEmail"}}
                      @deletePost={{@controller.deletePost}}
                      @permanentlyDeletePost={{@controller.permanentlyDeletePost}}
                      @recoverPost={{@controller.recoverPost}}
                      @expandHidden={{@controller.expandHidden}}
                      @toggleBookmark={{@controller.toggleBookmark}}
                      @togglePostType={{@controller.togglePostType}}
                      @rebakePost={{@controller.rebakePost}}
                      @changePostOwner={{@controller.changePostOwner}}
                      @grantBadge={{@controller.grantBadge}}
                      @changeNotice={{@controller.changeNotice}}
                      @lockPost={{@controller.lockPost}}
                      @unlockPost={{@controller.unlockPost}}
                      @unhidePost={{@controller.unhidePost}}
                      @replyToPost={{@controller.replyToPost}}
                      @toggleWiki={{@controller.toggleWiki}}
                      @showTopReplies={{@controller.showTopReplies}}
                      @cancelFilter={{@controller.cancelFilter}}
                      @removeAllowedUser={{@controller.removeAllowedUser}}
                      @removeAllowedGroup={{@controller.removeAllowedGroup}}
                      @topVisibleChanged={{@controller.topVisibleChanged}}
                      @currentPostChanged={{@controller.currentPostChanged}}
                      @currentPostScrolled={{@controller.currentPostScrolled}}
                      @bottomVisibleChanged={{@controller.bottomVisibleChanged}}
                      @togglePostSelection={{@controller.togglePostSelection}}
                      @selectReplies={{@controller.selectReplies}}
                      @selectBelow={{@controller.selectBelow}}
                      @fillGapBefore={{@controller.fillGapBefore}}
                      @fillGapAfter={{@controller.fillGapAfter}}
                      @showInvite={{routeAction "showInvite"}}
                      @showPagePublish={{routeAction "showPagePublish"}}
                      @filteringRepliesToPostNumber={{@controller.replies_to_post_number}}
                      @updateTopicPageQueryParams={{@controller.updateTopicPageQueryParams}}
                      @postSelected={{@controller.postSelected}}
                      @topicPageQueryParams={{@controller.topicPageQueryParams}}
                      @topic={{@controller.model}}
                    />
                  {{/unless}}

                  {{#if @controller.model.postStream.lastPostNotLoaded}}
                    {{hideScrollableContent "below"}}
                  {{/if}}
                </div>
                <div id="topic-bottom"></div>

                <DConditionalLoadingSpinner
                  @condition={{@controller.model.postStream.loadingFilter}}
                >
                  {{#if @controller.loadedAllPosts}}

                    {{#if @controller.model.pending_posts}}
                      <div class="pending-posts">
                        {{#each @controller.model.pending_posts as |pending|}}
                          <div
                            class="reviewable-item"
                            data-reviewable-id={{pending.id}}
                          >
                            <div class="reviewable-meta-data">
                              <span class="reviewable-type">
                                {{i18n "review.awaiting_approval"}}
                              </span>
                              <span class="created-at">
                                {{dAgeWithTooltip pending.created_at}}
                              </span>
                            </div>
                            <div class="post-contents-wrapper">
                              <ReviewableCreatedBy
                                @user={{@controller.currentUser}}
                              />
                              <div class="post-contents">
                                <ReviewableCreatedByName
                                  @user={{@controller.currentUser}}
                                />
                                <div class="post-body">
                                  <DCookText @rawText={{pending.raw}} />
                                </div>
                              </div>
                            </div>
                            <div class="reviewable-actions">
                              <PluginOutlet
                                @name="topic-additional-reviewable-actions"
                                @outletArgs={{lazyHash pending=pending}}
                              />
                              <DButton
                                @label="review.delete"
                                @icon="trash-can"
                                @action={{fn @controller.deletePending pending}}
                                class="btn-danger"
                              />
                            </div>
                          </div>
                        {{/each}}
                      </div>
                    {{/if}}

                    {{#if @controller.model.queued_posts_count}}
                      <div class="has-pending-posts">
                        <div>
                          {{trustHTML
                            (i18n
                              "review.topic_has_pending"
                              count=@controller.model.queued_posts_count
                            )
                          }}
                        </div>

                        <LinkTo
                          @route="review"
                          @query={{hash
                            topic_id=@controller.model.id
                            type="ReviewableQueuedPost"
                            status="pending"
                          }}
                        >
                          {{i18n "review.view_pending"}}
                        </LinkTo>
                      </div>
                    {{/if}}

                    <SlowModeInfo
                      @topic={{@controller.model}}
                      @user={{@controller.currentUser}}
                    />

                    <TopicTimerInfo
                      @topicClosed={{@controller.model.closed}}
                      @statusType={{@controller.model.topic_timer.status_type}}
                      @statusUpdate={{@controller.model.topic_status_update}}
                      @executeAt={{@controller.model.topic_timer.execute_at}}
                      @basedOnLastPost={{@controller.model.topic_timer.based_on_last_post}}
                      @durationMinutes={{@controller.model.topic_timer.duration_minutes}}
                      @categoryId={{@controller.model.topic_timer.category_id}}
                      @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                      @removeTopicTimer={{fn
                        @controller.removeTopicTimer
                        @controller.model.topic_timer.status_type
                        "topic_timer"
                      }}
                    />

                    {{#if @controller.showSelectedPostsAtBottom}}
                      <div
                        class="selected-posts
                          {{unless @controller.multiSelect 'hidden'}}
                          {{if @controller.showSelectedPostsAtBottom 'hidden'}}"
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
                    {{/if}}

                  {{/if}}
                </DConditionalLoadingSpinner>

                <PluginOutlet
                  @name="topic-area-bottom"
                  @connectorTagName="div"
                  @outletArgs={{lazyHash model=@controller.model}}
                />
              </section>
            </div>

          </div>
          {{#if @controller.loadedAllPosts}}
            {{#if @controller.session.showSignupCta}}
              {{! replace "Log In to Reply" with the infobox }}
              <SignupCta />
            {{else}}
              {{#if @controller.currentUser}}
                <span>
                  <PluginOutlet
                    @name="topic-above-footer-buttons"
                    @connectorTagName="div"
                    @outletArgs={{lazyHash model=@controller.model}}
                  />
                </span>

                {{#if @controller.showTopicFooterButtons}}
                  <TopicFooterButtons
                    @topic={{@controller.model}}
                    @toggleMultiSelect={{@controller.toggleMultiSelect}}
                    @showTopicSlowModeUpdate={{routeAction
                      "showTopicSlowModeUpdate"
                    }}
                    @deleteTopic={{@controller.deleteTopic}}
                    @recoverTopic={{@controller.recoverTopic}}
                    @toggleClosed={{@controller.toggleClosed}}
                    @toggleArchived={{@controller.toggleArchived}}
                    @toggleVisibility={{@controller.toggleVisibility}}
                    @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                    @showFeatureTopic={{routeAction "showFeatureTopic"}}
                    @showChangeTimestamp={{routeAction "showChangeTimestamp"}}
                    @resetBumpDate={{@controller.resetBumpDate}}
                    @convertToPublicTopic={{@controller.convertToPublicTopic}}
                    @convertToPrivateMessage={{@controller.convertToPrivateMessage}}
                    @toggleBookmark={{@controller.toggleBookmark}}
                    @showFlagTopic={{routeAction "showFlagTopic"}}
                    @toggleArchiveMessage={{@controller.toggleArchiveMessage}}
                    @editFirstPost={{@controller.editFirstPost}}
                    @deferTopic={{@controller.deferTopic}}
                    @replyToPost={{@controller.replyToPost}}
                  />
                {{/if}}
              {{else}}
                <AnonymousTopicFooterButtons @topic={{@controller.model}} />
              {{/if}}
            {{/if}}

            <br />

            <span>
              <PluginOutlet
                @name="topic-above-suggested"
                @connectorTagName="div"
                @outletArgs={{lazyHash model=@controller.model}}
              />
            </span>

            <MoreTopics @topic={{@controller.model}} />
            <PluginOutlet
              @name="topic-below-suggested"
              @outletArgs={{lazyHash model=@controller.model}}
            />
          {{/if}}
          <EmbedTopicFooter @topic={{@controller.model}} />
          <EmbedModeComposer @topic={{@controller.model}} />
        {{else}}
          <div class="container">
            <DConditionalLoadingSpinner @condition={{@controller.noErrorYet}}>
              {{#if @controller.model.errorHtml}}
                <div class="not-found">{{trustHTML
                    @controller.model.errorHtml
                  }}</div>
              {{else}}
                <div class="topic-error">
                  <div>{{@controller.model.errorMessage}}</div>
                  {{#if @controller.model.noRetry}}
                    {{#unless @controller.currentUser}}
                      <DButton
                        @action={{routeAction "showLogin"}}
                        @icon="user"
                        @label="log_in"
                        class="btn-primary topic-retry"
                      />
                    {{/unless}}
                  {{else}}
                    <DButton
                      @action={{@controller.retryLoading}}
                      @icon="arrows-rotate"
                      @label="errors.buttons.again"
                      class="btn-primary topic-retry"
                    />
                  {{/if}}
                </div>
                <DConditionalLoadingSpinner
                  @condition={{@controller.retrying}}
                />
              {{/if}}
            </DConditionalLoadingSpinner>
          </div>
        {{/if}}

        {{#each (array @controller.model) as |topic|}}
          <PostTextSelection
            @quoteState={{@controller.quoteState}}
            @selectText={{@controller.selectText}}
            @buildQuoteMarkdown={{@controller.buildQuoteMarkdown}}
            @editPost={{@controller.editPost}}
            @topic={{topic}}
          />
        {{/each}}
      {{/if}}
    {{/if}}
  </DiscourseTopic>
</template>
