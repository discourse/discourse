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
import TopicContentLanguagePreferences from "discourse/components/topic-content-language-preferences";
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
    @enteredAt={{@controller.enteredAt}}
    @hasScrolled={{@controller.hasScrolled}}
    @multiSelect={{@controller.multiSelect}}
    @topic={{@controller.model}}
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
            @buildQuoteMarkdown={{nested.buildQuoteMarkdown}}
            @editPost={{nested.editPost}}
            @quoteState={{nested.quoteState}}
            @selectText={{nested.selectText}}
            @topic={{@controller.model}}
          />

          <div
            class="selected-posts nested-view__selected-posts
              {{unless nested.multiSelect 'hidden'}}"
          >
            <SelectedPosts
              @canChangeOwner={{nested.canChangeOwner}}
              @canDeleteSelected={{nested.canDeleteSelected}}
              @canDeselectAll={{nested.canDeselectAll}}
              @canMergePosts={{nested.canMergePosts}}
              @canMergeTopic={{nested.canMergeTopic}}
              @canSelectAll={{nested.canSelectAll}}
              @deleteSelected={{nested.deleteSelected}}
              @deselectAll={{nested.deselectAll}}
              @mergePosts={{nested.mergePosts}}
              @selectAll={{nested.selectAll}}
              @selectedPostsCount={{nested.selectedPostsCount}}
              @toggleMultiSelect={{nested.toggleMultiSelect}}
            />
          </div>

          <Nested
            @ancestorsTruncated={{nested.ancestorsTruncated}}
            @buffered={{nested.buffered}}
            @cancelEditingTopic={{nested.cancelEditingTopic}}
            @canEditTags={{nested.canEditTags}}
            @changeNotice={{nested.changeNotice}}
            @changePostOwner={{nested.changePostOwner}}
            @changeSort={{nested.changeSort}}
            @clearScrollAnchor={{nested.clearScrollAnchor}}
            @collapseReplies={{nested.collapseReplies}}
            @contextMode={{nested.contextMode}}
            @contextNoAncestors={{nested.contextNoAncestors}}
            @deletePost={{nested.deletePost}}
            @editingTopic={{nested.editingTopic}}
            @editPost={{nested.editPost}}
            @effectiveSort={{nested.effectiveSort}}
            @expansionState={{nested.expansionState}}
            @fetchedChildrenCache={{nested.fetchedChildrenCache}}
            @finishedEditingTopic={{nested.finishedEditingTopic}}
            @grantBadge={{nested.grantBadge}}
            @hasMoreRoots={{nested.hasMoreRoots}}
            @initialFocusedPath={{nested.initialFocusedPath}}
            @loadingMore={{nested.loadingMore}}
            @loadMoreRoots={{nested.loadMoreRoots}}
            @loadNewRoots={{nested.loadNewRoots}}
            @lockPost={{nested.lockPost}}
            @minimumRequiredTags={{nested.minimumRequiredTags}}
            @multiSelect={{nested.multiSelect}}
            @newRootPostCount={{nested.newRootPostCount}}
            @opPost={{nested.opPost}}
            @permanentlyDeletePost={{nested.permanentlyDeletePost}}
            @pinnedPostIds={{nested.pinnedPostIds}}
            @postNumber={{nested.postNumber}}
            @postSelected={{nested.postSelected}}
            @rebakePost={{nested.rebakePost}}
            @recoverPost={{nested.recoverPost}}
            @replyToPost={{nested.replyToPost}}
            @rootNodes={{nested.rootNodes}}
            @saveScrollPosition={{nested.saveScrollPosition}}
            @scrollAnchor={{nested.scrollAnchor}}
            @selectBelow={{nested.selectBelow}}
            @selectReplies={{nested.selectReplies}}
            @setFocusedPostNumber={{nested.setFocusedPostNumber}}
            @showActivityLog={{nested.showActivityLog}}
            @showCategoryChooser={{nested.showCategoryChooser}}
            @showFlags={{nested.showFlags}}
            @showHistory={{nested.showHistory}}
            @showPagePublish={{nested.showPagePublish}}
            @sort={{nested.sort}}
            @startEditingTopic={{nested.startEditingTopic}}
            @targetPostNumber={{nested.targetPostNumber}}
            @togglePostSelection={{nested.togglePostSelection}}
            @togglePostType={{nested.togglePostType}}
            @toggleWiki={{nested.toggleWiki}}
            @topic={{@controller.model}}
            @topicCategoryChanged={{nested.topicCategoryChanged}}
            @topicTagsChanged={{nested.topicTagsChanged}}
            @unhidePost={{nested.unhidePost}}
            @unlockPost={{nested.unlockPost}}
            @viewFullThread={{nested.viewFullThread}}
            @viewParentContext={{nested.viewParentContext}}
          />
        {{/let}}
      {{else}}

        {{#unless @controller.shouldHideScrollableContentAbove}}
          <div class="container">
            <DiscourseBanner
              @hide={{@controller.model.errorLoading}}
              @overlay={{@controller.hasScrolled}}
            />
          </div>
        {{/unless}}

        {{#unless @controller.shouldHideScrollableContentAbove}}
          {{#if @controller.showSharedDraftControls}}
            <SharedDraftControls @topic={{@controller.model}} />
          {{/if}}

          <span>
            <PluginOutlet
              @connectorTagName="div"
              @name="topic-above-post-stream"
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
              @model={{@controller.model}}
              @save={{@controller.finishedEditingTopic}}
            >
              {{#if @controller.editingTopic}}
                <div class="edit-topic-title">
                  <PrivateMessageGlyph
                    @shouldShow={{@controller.model.isPrivateMessage}}
                  />

                  <TopicTitleEditor
                    @buffered={{@controller.buffered}}
                    @bufferedTitle={{@controller.buffered.title}}
                    @isEditingLocalization={{@controller.editingTopicLocalization}}
                    @model={{@controller.model}}
                    @translationLocale={{@controller.translationLocale}}
                    @translationTitle={{@controller.translationTitle}}
                  />

                  <TopicMetadata
                    @buffered={{@controller.buffered}}
                    @canEditTags={{@controller.canEditTags}}
                    @minimumRequiredTags={{@controller.minimumRequiredTags}}
                    @model={{@controller.model}}
                    @onCancel={{@controller.cancelEditingTopic}}
                    @onSave={{@controller.finishedEditingTopic}}
                    @showCategoryChooser={{@controller.showCategoryChooser}}
                    @topicCategoryChanged={{@controller.topicCategoryChanged}}
                    @topicTagsChanged={{@controller.topicTagsChanged}}
                  >
                    {{#if @controller.canRemoveTopicFeaturedLink}}
                      <a
                        class="remove-featured-link"
                        href
                        title={{i18n "composer.remove_featured_link"}}
                        {{on "click" @controller.removeFeaturedLink}}
                      >
                        {{dIcon "circle-xmark"}}
                        {{@controller.featuredLinkDomain}}
                      </a>
                    {{/if}}
                  </TopicMetadata>
                </div>

              {{else}}
                <h1
                  {{! Prevent duplicating the topic title heading on screen readers when the header is displaying the title
                in the header }}
                  aria-hidden={{booleanString
                    @controller.titleIsVisibleOnHeader
                  }}
                  data-topic-id={{@controller.model.id}}
                >
                  {{#unless @controller.model.is_warning}}
                    {{#if @controller.canSendPms}}
                      <PrivateMessageGlyph
                        @ariaLabel="user.messages.inbox"
                        @href={{@controller.pmPath}}
                        @shouldShow={{@controller.model.isPrivateMessage}}
                        @title="topic_statuses.personal_message.title"
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
                      class="fancy-title"
                      href={{@controller.model.url}}
                      {{on "click" @controller.handleTitleClick}}
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
                    class="topic-category"
                    @topic={{@controller.model}}
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
                      rel="noopener noreferrer"
                      target="_blank"
                    >{{@controller.model.publishedPage.url}}</a>
                  </div>
                </div>
                <div class="controls">
                  <DButton
                    @action={{routeAction "showPagePublish"}}
                    @icon="file"
                    @label="topic.publish_page.publishing_settings"
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
                @canChangeOwner={{@controller.canChangeOwner}}
                @canDeleteSelected={{@controller.canDeleteSelected}}
                @canDeselectAll={{@controller.canDeselectAll}}
                @canMergePosts={{@controller.canMergePosts}}
                @canMergeTopic={{@controller.canMergeTopic}}
                @canSelectAll={{@controller.canSelectAll}}
                @deleteSelected={{@controller.deleteSelected}}
                @deselectAll={{@controller.deselectAll}}
                @mergePosts={{@controller.mergePosts}}
                @selectAll={{@controller.selectAll}}
                @selectedPostsCount={{@controller.selectedPostsCount}}
                @toggleMultiSelect={{@controller.toggleMultiSelect}}
              />
            </div>

            {{#if
              (and @controller.showBottomTopicMap @controller.loadedAllPosts)
            }}
              <div class="topic-map --bottom">
                <TopicMap
                  @model={{@controller.model}}
                  @postStream={{@controller.model.postStream}}
                  @removeAllowedGroup={{@controller.removeAllowedGroup}}
                  @removeAllowedUser={{@controller.removeAllowedUser}}
                  @showInvite={{routeAction "showInvite"}}
                  @showPMMap={{eq
                    @controller.model.archetype
                    "private_message"
                  }}
                  @topicDetails={{@controller.model.details}}
                />
              </div>
            {{/if}}

            <PluginOutlet @connectorTagName="div" @name="above-timeline" />

            <TopicNavigation
              class="topic-navigation"
              @jumpToDate={{@controller.jumpToDate}}
              @jumpToIndex={{@controller.jumpToIndex}}
              @topic={{@controller.model}}
              as |info toggleProgressExpansion|
            >
              <PluginOutlet
                @connectorTagName="div"
                @name="topic-navigation"
                @outletArgs={{lazyHash
                  topic=@controller.model
                  renderTimeline=info.renderTimeline
                  topicProgressExpanded=info.topicProgressExpanded
                }}
              />

              {{#if info.renderTimeline}}
                <TopicTimeline
                  @convertToPrivateMessage={{@controller.convertToPrivateMessage}}
                  @convertToPublicTopic={{@controller.convertToPublicTopic}}
                  @deleteTopic={{@controller.deleteTopic}}
                  @enteredIndex={{@controller.enteredIndex}}
                  @fullscreen={{info.topicProgressExpanded}}
                  @info={{info}}
                  @jumpBottom={{@controller.jumpBottom}}
                  @jumpEnd={{@controller.jumpEnd}}
                  @jumpToIndex={{@controller.jumpToIndex}}
                  @jumpTop={{@controller.jumpTop}}
                  @jumpToPostPrompt={{@controller.jumpToPostPrompt}}
                  @model={{@controller.model}}
                  @prevEvent={{info.prevEvent}}
                  @recoverTopic={{@controller.recoverTopic}}
                  @replyToPost={{@controller.replyToPost}}
                  @resetBumpDate={{@controller.resetBumpDate}}
                  @showChangeTimestamp={{routeAction "showChangeTimestamp"}}
                  @showFeatureTopic={{routeAction "showFeatureTopic"}}
                  @showTopicSlowModeUpdate={{routeAction
                    "showTopicSlowModeUpdate"
                  }}
                  @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                  @showTopReplies={{@controller.showTopReplies}}
                  @toggleArchived={{@controller.toggleArchived}}
                  @toggleClosed={{@controller.toggleClosed}}
                  @toggleMultiSelect={{@controller.toggleMultiSelect}}
                  @toggleVisibility={{@controller.toggleVisibility}}
                />
              {{else}}
                <TopicProgress
                  @jumpToPost={{@controller.jumpToPost}}
                  @onExpandToggle={{toggleProgressExpansion}}
                  @prevEvent={{info.prevEvent}}
                  @topic={{@controller.model}}
                >
                  <PluginOutlet
                    @connectorTagName="div"
                    @name="before-topic-progress"
                    @outletArgs={{lazyHash
                      model=@controller.model
                      jumpToPost=@controller.jumpToPost
                    }}
                  />
                  <TopicAdminMenu
                    @convertToPrivateMessage={{@controller.convertToPrivateMessage}}
                    @convertToPublicTopic={{@controller.convertToPublicTopic}}
                    @deleteTopic={{@controller.deleteTopic}}
                    @recoverTopic={{@controller.recoverTopic}}
                    @resetBumpDate={{@controller.resetBumpDate}}
                    @showChangeTimestamp={{routeAction "showChangeTimestamp"}}
                    @showFeatureTopic={{routeAction "showFeatureTopic"}}
                    @showTopicSlowModeUpdate={{routeAction
                      "showTopicSlowModeUpdate"
                    }}
                    @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                    @toggleArchived={{@controller.toggleArchived}}
                    @toggleClosed={{@controller.toggleClosed}}
                    @toggleMultiSelect={{@controller.toggleMultiSelect}}
                    @toggleVisibility={{@controller.toggleVisibility}}
                    @topic={{@controller.model}}
                  />
                  {{#if @controller.model.has_localized_content}}
                    <TopicContentLanguagePreferences />
                  {{/if}}
                </TopicProgress>
              {{/if}}

              <PluginOutlet
                @connectorTagName="div"
                @name="topic-navigation-bottom"
                @outletArgs={{lazyHash model=@controller.model}}
              />
            </TopicNavigation>

            <div class="row">
              <section
                class="topic-area"
                data-topic-id={{@controller.model.id}}
                id="topic"
              >
                <div class="posts-wrapper">
                  <span>
                    <PluginOutlet
                      @connectorTagName="div"
                      @name="topic-above-posts"
                      @outletArgs={{lazyHash model=@controller.model}}
                    />
                  </span>

                  {{#if @controller.model.postStream.firstPostNotLoaded}}
                    {{hideScrollableContent "above"}}
                  {{/if}}

                  {{#unless @controller.model.postStream.loadingFilter}}
                    <PostStream
                      @bottomVisibleChanged={{@controller.bottomVisibleChanged}}
                      @cancelFilter={{@controller.cancelFilter}}
                      @canCreatePost={{@controller.model.details.can_create_post}}
                      @changeNotice={{@controller.changeNotice}}
                      @changePostOwner={{@controller.changePostOwner}}
                      @currentPostChanged={{@controller.currentPostChanged}}
                      @currentPostScrolled={{@controller.currentPostScrolled}}
                      @deletePost={{@controller.deletePost}}
                      @editPost={{@controller.editPost}}
                      @expandHidden={{@controller.expandHidden}}
                      @fillGapAfter={{@controller.fillGapAfter}}
                      @fillGapBefore={{@controller.fillGapBefore}}
                      @filteredPostsCount={{@controller.model.postStream.filteredPostsCount}}
                      @filteringRepliesToPostNumber={{@controller.replies_to_post_number}}
                      @gaps={{@controller.model.postStream.gaps}}
                      @grantBadge={{@controller.grantBadge}}
                      @highestPostNumber={{@controller.highestPostNumber}}
                      @lastReadPostNumber={{@controller.userLastReadPostNumber}}
                      @lockPost={{@controller.lockPost}}
                      @multiSelect={{@controller.multiSelect}}
                      @permanentlyDeletePost={{@controller.permanentlyDeletePost}}
                      @postSelected={{@controller.postSelected}}
                      @postStream={{@controller.model.postStream}}
                      @rebakePost={{@controller.rebakePost}}
                      @recoverPost={{@controller.recoverPost}}
                      @removeAllowedGroup={{@controller.removeAllowedGroup}}
                      @removeAllowedUser={{@controller.removeAllowedUser}}
                      @replyToPost={{@controller.replyToPost}}
                      @selectBelow={{@controller.selectBelow}}
                      @selectedPostsCount={{@controller.selectedPostsCount}}
                      @selectedQuery={{@controller.selectedQuery}}
                      @selectReplies={{@controller.selectReplies}}
                      @showFlags={{@controller.showPostFlags}}
                      @showHistory={{routeAction "showHistory"}}
                      @showInvite={{routeAction "showInvite"}}
                      @showLogin={{routeAction "showLogin"}}
                      @showPagePublish={{routeAction "showPagePublish"}}
                      @showRawEmail={{routeAction "showRawEmail"}}
                      @showReadIndicator={{@controller.model.show_read_indicator}}
                      @showTopReplies={{@controller.showTopReplies}}
                      @streamFilters={{@controller.model.postStream.streamFilters}}
                      @toggleBookmark={{@controller.toggleBookmark}}
                      @togglePostSelection={{@controller.togglePostSelection}}
                      @togglePostType={{@controller.togglePostType}}
                      @toggleWiki={{@controller.toggleWiki}}
                      @topic={{@controller.model}}
                      @topicPageQueryParams={{@controller.topicPageQueryParams}}
                      @topVisibleChanged={{@controller.topVisibleChanged}}
                      @unhidePost={{@controller.unhidePost}}
                      @unlockPost={{@controller.unlockPost}}
                      @updateTopicPageQueryParams={{@controller.updateTopicPageQueryParams}}
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
                                class="btn-danger"
                                @action={{fn @controller.deletePending pending}}
                                @icon="trash-can"
                                @label="review.delete"
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
                          @query={{hash
                            topic_id=@controller.model.id
                            type="ReviewableQueuedPost"
                            status="pending"
                          }}
                          @route="review"
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
                      @basedOnLastPost={{@controller.model.topic_timer.based_on_last_post}}
                      @categoryId={{@controller.model.topic_timer.category_id}}
                      @durationMinutes={{@controller.model.topic_timer.duration_minutes}}
                      @executeAt={{@controller.model.topic_timer.execute_at}}
                      @removeTopicTimer={{fn
                        @controller.removeTopicTimer
                        @controller.model.topic_timer.status_type
                        "topic_timer"
                      }}
                      @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                      @statusType={{@controller.model.topic_timer.status_type}}
                      @statusUpdate={{@controller.model.topic_status_update}}
                      @topicClosed={{@controller.model.closed}}
                    />

                    {{#if @controller.showSelectedPostsAtBottom}}
                      <div
                        class="selected-posts
                          {{unless @controller.multiSelect 'hidden'}}
                          {{if @controller.showSelectedPostsAtBottom 'hidden'}}"
                      >
                        <SelectedPosts
                          @canChangeOwner={{@controller.canChangeOwner}}
                          @canDeleteSelected={{@controller.canDeleteSelected}}
                          @canDeselectAll={{@controller.canDeselectAll}}
                          @canMergePosts={{@controller.canMergePosts}}
                          @canMergeTopic={{@controller.canMergeTopic}}
                          @canSelectAll={{@controller.canSelectAll}}
                          @deleteSelected={{@controller.deleteSelected}}
                          @deselectAll={{@controller.deselectAll}}
                          @mergePosts={{@controller.mergePosts}}
                          @selectAll={{@controller.selectAll}}
                          @selectedPostsCount={{@controller.selectedPostsCount}}
                          @toggleMultiSelect={{@controller.toggleMultiSelect}}
                        />
                      </div>
                    {{/if}}

                  {{/if}}
                </DConditionalLoadingSpinner>

                <PluginOutlet
                  @connectorTagName="div"
                  @name="topic-area-bottom"
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
                    @connectorTagName="div"
                    @name="topic-above-footer-buttons"
                    @outletArgs={{lazyHash model=@controller.model}}
                  />
                </span>

                {{#if @controller.showTopicFooterButtons}}
                  <TopicFooterButtons
                    @convertToPrivateMessage={{@controller.convertToPrivateMessage}}
                    @convertToPublicTopic={{@controller.convertToPublicTopic}}
                    @deferTopic={{@controller.deferTopic}}
                    @deleteTopic={{@controller.deleteTopic}}
                    @editFirstPost={{@controller.editFirstPost}}
                    @recoverTopic={{@controller.recoverTopic}}
                    @replyToPost={{@controller.replyToPost}}
                    @resetBumpDate={{@controller.resetBumpDate}}
                    @showChangeTimestamp={{routeAction "showChangeTimestamp"}}
                    @showFeatureTopic={{routeAction "showFeatureTopic"}}
                    @showFlagTopic={{routeAction "showFlagTopic"}}
                    @showTopicSlowModeUpdate={{routeAction
                      "showTopicSlowModeUpdate"
                    }}
                    @showTopicTimerModal={{routeAction "showTopicTimerModal"}}
                    @toggleArchived={{@controller.toggleArchived}}
                    @toggleArchiveMessage={{@controller.toggleArchiveMessage}}
                    @toggleBookmark={{@controller.toggleBookmark}}
                    @toggleClosed={{@controller.toggleClosed}}
                    @toggleMultiSelect={{@controller.toggleMultiSelect}}
                    @toggleVisibility={{@controller.toggleVisibility}}
                    @topic={{@controller.model}}
                  />
                {{/if}}
              {{else}}
                <AnonymousTopicFooterButtons @topic={{@controller.model}} />
              {{/if}}
            {{/if}}

            <br />

            <span>
              <PluginOutlet
                @connectorTagName="div"
                @name="topic-above-suggested"
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
                        class="btn-primary topic-retry"
                        @action={{routeAction "showLogin"}}
                        @icon="user"
                        @label="log_in"
                      />
                    {{/unless}}
                  {{else}}
                    <DButton
                      class="btn-primary topic-retry"
                      @action={{@controller.retryLoading}}
                      @icon="arrows-rotate"
                      @label="errors.buttons.again"
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
            @buildQuoteMarkdown={{@controller.buildQuoteMarkdown}}
            @editPost={{@controller.editPost}}
            @quoteState={{@controller.quoteState}}
            @selectText={{@controller.selectText}}
            @topic={{topic}}
          />
        {{/each}}
      {{/if}}
    {{/if}}
  </DiscourseTopic>
</template>
