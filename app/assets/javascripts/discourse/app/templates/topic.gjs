import RouteTemplate from 'ember-route-template'
import and from "truth-helpers/helpers/and";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import DiscourseTopic from "discourse/components/discourse-topic";
import stickyAvatars from "discourse/modifiers/sticky-avatars";
import AddCategoryTagClasses from "discourse/components/add-category-tag-classes";
import AddTopicStatusClasses from "discourse/components/add-topic-status-classes";
import bodyClass from "discourse/helpers/body-class";
import { concat, hash, fn, array } from "@ember/helper";
import DiscourseBanner from "discourse/components/discourse-banner";
import SharedDraftControls from "discourse/components/shared-draft-controls";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicTitle from "discourse/components/topic-title";
import PrivateMessageGlyph from "discourse/components/private-message-glyph";
import TextField from "discourse/components/text-field";
import CategoryChooser from "select-kit/components/category-chooser";
import MiniTagChooser from "select-kit/components/mini-tag-chooser";
import DButton from "discourse/components/d-button";
import i18n from "discourse/helpers/i18n";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import TopicStatus from "discourse/components/topic-status";
import htmlSafe from "discourse/helpers/html-safe";
import TopicCategory from "discourse/components/topic-category";
import routeAction from "discourse/helpers/route-action";
import SelectedPosts from "discourse/components/selected-posts";
import TopicMap from "discourse/components/topic-map/index";
import eq from "truth-helpers/helpers/eq";
import TopicNavigation from "discourse/components/topic-navigation";
import TopicTimeline from "discourse/components/topic-timeline";
import TopicProgress from "discourse/components/topic-progress";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import ScrollingPostStream from "discourse/components/scrolling-post-stream";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import ReviewableCreatedBy from "discourse/components/reviewable-created-by";
import ReviewableCreatedByName from "discourse/components/reviewable-created-by-name";
import CookText from "discourse/components/cook-text";
import { LinkTo } from "@ember/routing";
import SlowModeInfo from "discourse/components/slow-mode-info";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import SignupCta from "discourse/components/signup-cta";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";
import AnonymousTopicFooterButtons from "discourse/components/anonymous-topic-footer-buttons";
import MoreTopics from "discourse/components/more-topics";
import PostTextSelection from "discourse/components/post-text-selection";
export default RouteTemplate(<template>{{#let @controller.model.postStream as |postStream|}}
  {{#unless (and postStream.loaded postStream.loadedAllPosts)}}
    {{hideApplicationFooter}}
  {{/unless}}
{{/let}}

<DiscourseTopic {{stickyAvatars}} @multiSelect={{@controller.multiSelect}} @enteredAt={{@controller.enteredAt}} @topic={{@controller.model}} @hasScrolled={{@controller.hasScrolled}}>
  {{#if @controller.model}}
    <AddCategoryTagClasses @category={{@controller.model.category}} @tags={{@controller.model.tags}} />
    <AddTopicStatusClasses @topic={{@controller.model}} />
    {{bodyClass (concat "archetype-" @controller.model.archetype)}}
    <div class="container">
      <DiscourseBanner @overlay={{@controller.hasScrolled}} @hide={{@controller.model.errorLoading}} />
    </div>
  {{/if}}

  {{#if @controller.showSharedDraftControls}}
    <SharedDraftControls @topic={{@controller.model}} />
  {{/if}}

  <span>
    <PluginOutlet @name="topic-above-post-stream" @connectorTagName="div" @outletArgs={{hash model=@controller.model editFirstPost=(action "editFirstPost")}} />
  </span>

  {{#if @controller.model.postStream.loaded}}
    {{#if @controller.model.postStream.firstPostPresent}}
      <TopicTitle @cancelled={{action "cancelEditingTopic"}} @save={{action "finishedEditingTopic"}} @model={{@controller.model}}>
        {{#if @controller.editingTopic}}
          <div class="edit-topic-title">
            <PrivateMessageGlyph @shouldShow={{@controller.model.isPrivateMessage}} />

            <div class="edit-title__wrapper">
              <PluginOutlet @name="edit-topic-title" @outletArgs={{hash model=@controller.model buffered=@controller.buffered}}>
                <TextField @id="edit-title" @value={{@controller.buffered.title}} @maxlength={{@controller.siteSettings.max_topic_title_length}} @autofocus="true" />
              </PluginOutlet>
            </div>

            {{#if @controller.showCategoryChooser}}
              <div class="edit-category__wrapper">
                <PluginOutlet @name="edit-topic-category" @outletArgs={{hash model=@controller.model buffered=@controller.buffered}}>
                  <CategoryChooser @value={{@controller.buffered.category_id}} @onChange={{action "topicCategoryChanged"}} class="small" />
                </PluginOutlet>
              </div>
            {{/if}}

            {{#if @controller.canEditTags}}
              <div class="edit-tags__wrapper">
                <PluginOutlet @name="edit-topic-tags" @outletArgs={{hash model=@controller.model buffered=@controller.buffered}}>
                  <MiniTagChooser @value={{@controller.buffered.tags}} @onChange={{action "topicTagsChanged"}} @options={{hash filterable=true categoryId=@controller.buffered.category_id minimum=@controller.minimumRequiredTags filterPlaceholder="tagging.choose_for_topic" useHeaderFilter=true}} />
                </PluginOutlet>
              </div>
            {{/if}}

            <PluginOutlet @name="edit-topic" @connectorTagName="div" @outletArgs={{hash model=@controller.model buffered=@controller.buffered}} />

            <div class="edit-controls">
              <DButton @action={{action "finishedEditingTopic"}} @icon="check" @ariaLabel="composer.save_edit" class="btn-primary submit-edit" />
              <DButton @action={{action "cancelEditingTopic"}} @icon="xmark" @ariaLabel="composer.cancel" class="btn-default cancel-edit" />

              {{#if @controller.canRemoveTopicFeaturedLink}}
                <a href {{on "click" @controller.removeFeaturedLink}} class="remove-featured-link" title={{i18n "composer.remove_featured_link"}}>
                  {{icon "circle-xmark"}}
                  {{@controller.featuredLinkDomain}}
                </a>
              {{/if}}
            </div>
          </div>

        {{else}}
          <h1 data-topic-id={{@controller.model.id}}>
            {{#unless @controller.model.is_warning}}
              {{#if @controller.canSendPms}}
                <PrivateMessageGlyph @shouldShow={{@controller.model.isPrivateMessage}} @href={{@controller.pmPath}} @title="topic_statuses.personal_message.title" @ariaLabel="user.messages.inbox" />
              {{else}}
                <PrivateMessageGlyph @shouldShow={{@controller.model.isPrivateMessage}} />
              {{/if}}
            {{/unless}}

            {{#if @controller.model.details.loaded}}
              <TopicStatus @topic={{@controller.model}} />
              <a href={{@controller.model.url}} {{on "click" @controller.jumpTop}} class="fancy-title">
                {{htmlSafe @controller.model.fancyTitle}}
              </a>
            {{/if}}

            {{#if @controller.model.details.can_edit}}
              <a href {{on "click" @controller.editTopic}} class="edit-topic" title={{i18n "edit_topic"}}>{{icon "pencil"}}</a>
            {{/if}}

            <PluginOutlet @name="topic-title-suffix" @outletArgs={{hash model=@controller.model}} />
          </h1>

          <PluginOutlet @name="topic-category-wrapper" @outletArgs={{hash topic=@controller.model}}>
            <TopicCategory @topic={{@controller.model}} class="topic-category" />
          </PluginOutlet>

        {{/if}}
      </TopicTitle>

      {{#if @controller.model.publishedPage}}
        <div class="published-page-notice">
          <div class="details">
            {{#if @controller.model.publishedPage.public}}
              <span class="is-public">{{i18n "topic.publish_page.public"}}</span>
            {{/if}}
            {{i18n "topic.publish_page.topic_published"}}
            <div>
              <a href={{@controller.model.publishedPage.url}} target="_blank" rel="noopener noreferrer">{{@controller.model.publishedPage.url}}</a>
            </div>
          </div>
          <div class="controls">
            <DButton @icon="file" @label="topic.publish_page.publishing_settings" @action={{routeAction "showPagePublish"}} />
          </div>
        </div>
      {{/if}}

    {{/if}}

    <div class="container posts">
      <div class="selected-posts {{unless @controller.multiSelect "hidden"}}">
        <SelectedPosts @selectedPostsCount={{@controller.selectedPostsCount}} @canSelectAll={{@controller.canSelectAll}} @canDeselectAll={{@controller.canDeselectAll}} @canDeleteSelected={{@controller.canDeleteSelected}} @canMergeTopic={{@controller.canMergeTopic}} @canChangeOwner={{@controller.canChangeOwner}} @canMergePosts={{@controller.canMergePosts}} @toggleMultiSelect={{action "toggleMultiSelect"}} @mergePosts={{action "mergePosts"}} @deleteSelected={{action "deleteSelected"}} @deselectAll={{action "deselectAll"}} @selectAll={{action "selectAll"}} />
      </div>

      {{#if (and @controller.showBottomTopicMap @controller.loadedAllPosts)}}
        <div class="topic-map --bottom">
          <TopicMap @model={{@controller.model}} @topicDetails={{@controller.model.details}} @postStream={{@controller.model.postStream}} @showPMMap={{eq @controller.model.archetype "private_message"}} @showInvite={{routeAction "showInvite"}} @removeAllowedGroup={{action "removeAllowedGroup"}} @removeAllowedUser={{action "removeAllowedUser"}} />
        </div>
      {{/if}}

      <PluginOutlet @name="above-timeline" @connectorTagName="div" />

      <TopicNavigation @topic={{@controller.model}} @jumpToDate={{action "jumpToDate"}} @jumpToIndex={{action "jumpToIndex"}} class="topic-navigation" as |info|>
        <PluginOutlet @name="topic-navigation" @connectorTagName="div" @outletArgs={{hash topic=@controller.model renderTimeline=info.renderTimeline topicProgressExpanded=info.topicProgressExpanded}} />
        {{#if info.renderTimeline}}
          <TopicTimeline @info={{info}} @model={{@controller.model}} @replyToPost={{action "replyToPost"}} @showTopReplies={{action "showTopReplies"}} @jumpToPostPrompt={{action "jumpToPostPrompt"}} @enteredIndex={{@controller.enteredIndex}} @prevEvent={{info.prevEvent}} @jumpTop={{action "jumpTop"}} @jumpBottom={{action "jumpBottom"}} @jumpEnd={{action "jumpEnd"}} @jumpToIndex={{action "jumpToIndex"}} @toggleMultiSelect={{action "toggleMultiSelect"}} @showTopicSlowModeUpdate={{routeAction "showTopicSlowModeUpdate"}} @deleteTopic={{action "deleteTopic"}} @recoverTopic={{action "recoverTopic"}} @toggleClosed={{action "toggleClosed"}} @toggleArchived={{action "toggleArchived"}} @toggleVisibility={{action "toggleVisibility"}} @showTopicTimerModal={{routeAction "showTopicTimerModal"}} @showFeatureTopic={{routeAction "showFeatureTopic"}} @showChangeTimestamp={{routeAction "showChangeTimestamp"}} @resetBumpDate={{action "resetBumpDate"}} @convertToPublicTopic={{action "convertToPublicTopic"}} @convertToPrivateMessage={{action "convertToPrivateMessage"}} @fullscreen={{info.topicProgressExpanded}} />
        {{else}}
          <TopicProgress @prevEvent={{info.prevEvent}} @topic={{@controller.model}} @expanded={{info.topicProgressExpanded}} @jumpToPost={{action "jumpToPost"}}>
            <span>
              <PluginOutlet @name="before-topic-progress" @connectorTagName="div" @outletArgs={{hash model=@controller.model jumpToPost=(action "jumpToPost")}} />
            </span>
            <TopicAdminMenu @topic={{@controller.model}} @toggleMultiSelect={{action "toggleMultiSelect"}} @showTopicSlowModeUpdate={{routeAction "showTopicSlowModeUpdate"}} @deleteTopic={{action "deleteTopic"}} @recoverTopic={{action "recoverTopic"}} @toggleClosed={{action "toggleClosed"}} @toggleArchived={{action "toggleArchived"}} @toggleVisibility={{action "toggleVisibility"}} @showTopicTimerModal={{routeAction "showTopicTimerModal"}} @showFeatureTopic={{routeAction "showFeatureTopic"}} @showChangeTimestamp={{routeAction "showChangeTimestamp"}} @resetBumpDate={{action "resetBumpDate"}} @convertToPublicTopic={{action "convertToPublicTopic"}} @convertToPrivateMessage={{action "convertToPrivateMessage"}} />
          </TopicProgress>
        {{/if}}

        <PluginOutlet @name="topic-navigation-bottom" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
      </TopicNavigation>

      <div class="row">
        <section class="topic-area" id="topic" data-topic-id={{@controller.model.id}}>

          <div class="posts-wrapper">
            <ConditionalLoadingSpinner @condition={{@controller.model.postStream.loadingAbove}} />

            <span>
              <PluginOutlet @name="topic-above-posts" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
            </span>

            {{#unless @controller.model.postStream.loadingFilter}}
              <ScrollingPostStream @posts={{@controller.postsToRender}} @canCreatePost={{@controller.model.details.can_create_post}} @multiSelect={{@controller.multiSelect}} @selectedPostsCount={{@controller.selectedPostsCount}} @filteredPostsCount={{@controller.model.postStream.filteredPostsCount}} @selectedQuery={{@controller.selectedQuery}} @gaps={{@controller.model.postStream.gaps}} @showReadIndicator={{@controller.model.show_read_indicator}} @streamFilters={{@controller.model.postStream.streamFilters}} @lastReadPostNumber={{@controller.userLastReadPostNumber}} @highestPostNumber={{@controller.highestPostNumber}} @showFlags={{action "showPostFlags"}} @editPost={{action "editPost"}} @showHistory={{routeAction "showHistory"}} @showLogin={{routeAction "showLogin"}} @showRawEmail={{routeAction "showRawEmail"}} @deletePost={{action "deletePost"}} @permanentlyDeletePost={{action "permanentlyDeletePost"}} @recoverPost={{action "recoverPost"}} @expandHidden={{action "expandHidden"}} @toggleBookmark={{action "toggleBookmark"}} @togglePostType={{action "togglePostType"}} @rebakePost={{action "rebakePost"}} @changePostOwner={{action "changePostOwner"}} @grantBadge={{action "grantBadge"}} @changeNotice={{action "changeNotice"}} @lockPost={{action "lockPost"}} @unlockPost={{action "unlockPost"}} @unhidePost={{action "unhidePost"}} @replyToPost={{action "replyToPost"}} @toggleWiki={{action "toggleWiki"}} @showTopReplies={{action "showTopReplies"}} @cancelFilter={{action "cancelFilter"}} @removeAllowedUser={{action "removeAllowedUser"}} @removeAllowedGroup={{action "removeAllowedGroup"}} @topVisibleChanged={{action "topVisibleChanged"}} @currentPostChanged={{action "currentPostChanged"}} @currentPostScrolled={{action "currentPostScrolled"}} @bottomVisibleChanged={{action "bottomVisibleChanged"}} @togglePostSelection={{action "togglePostSelection"}} @selectReplies={{action "selectReplies"}} @selectBelow={{action "selectBelow"}} @fillGapBefore={{action "fillGapBefore"}} @fillGapAfter={{action "fillGapAfter"}} @showInvite={{routeAction "showInvite"}} @showPagePublish={{routeAction "showPagePublish"}} />
            {{/unless}}

            <ConditionalLoadingSpinner @condition={{@controller.model.postStream.loadingBelow}} />
          </div>
          <div id="topic-bottom"></div>

          <ConditionalLoadingSpinner @condition={{@controller.model.postStream.loadingFilter}}>
            {{#if @controller.loadedAllPosts}}

              {{#if @controller.model.pending_posts}}
                <div class="pending-posts">
                  {{#each @controller.model.pending_posts as |pending|}}
                    <div class="reviewable-item" data-reviewable-id={{pending.id}}>
                      <div class="reviewable-meta-data">
                        <span class="reviewable-type">
                          {{i18n "review.awaiting_approval"}}
                        </span>
                        <span class="created-at">
                          {{ageWithTooltip pending.created_at}}
                        </span>
                      </div>
                      <div class="post-contents-wrapper">
                        <ReviewableCreatedBy @user={{@controller.currentUser}} />
                        <div class="post-contents">
                          <ReviewableCreatedByName @user={{@controller.currentUser}} />
                          <div class="post-body"><CookText @rawText={{pending.raw}} /></div>
                        </div>
                      </div>
                      <div class="reviewable-actions">
                        <PluginOutlet @name="topic-additional-reviewable-actions" @outletArgs={{hash pending=pending}} />
                        <DButton @label="review.delete" @icon="trash-can" @action={{fn (action "deletePending") pending}} class="btn-danger" />
                      </div>
                    </div>
                  {{/each}}
                </div>
              {{/if}}

              {{#if @controller.model.queued_posts_count}}
                <div class="has-pending-posts">
                  <div>
                    {{htmlSafe (i18n "review.topic_has_pending" count=@controller.model.queued_posts_count)}}
                  </div>

                  <LinkTo @route="review" @query={{hash topic_id=@controller.model.id type="ReviewableQueuedPost" status="pending"}}>
                    {{i18n "review.view_pending"}}
                  </LinkTo>
                </div>
              {{/if}}

              <SlowModeInfo @topic={{@controller.model}} @user={{@controller.currentUser}} @tagName />

              <TopicTimerInfo @topicClosed={{@controller.model.closed}} @statusType={{@controller.model.topic_timer.status_type}} @statusUpdate={{@controller.model.topic_status_update}} @executeAt={{@controller.model.topic_timer.execute_at}} @basedOnLastPost={{@controller.model.topic_timer.based_on_last_post}} @durationMinutes={{@controller.model.topic_timer.duration_minutes}} @categoryId={{@controller.model.topic_timer.category_id}} @showTopicTimerModal={{routeAction "showTopicTimerModal"}} @removeTopicTimer={{action "removeTopicTimer" @controller.model.topic_timer.status_type "topic_timer"}} />

              {{#if @controller.showSelectedPostsAtBottom}}
                <div class="selected-posts
                    {{unless @controller.multiSelect "hidden"}}
                    {{if @controller.showSelectedPostsAtBottom "hidden"}}">
                  <SelectedPosts @selectedPostsCount={{@controller.selectedPostsCount}} @canSelectAll={{@controller.canSelectAll}} @canDeselectAll={{@controller.canDeselectAll}} @canDeleteSelected={{@controller.canDeleteSelected}} @canMergeTopic={{@controller.canMergeTopic}} @canChangeOwner={{@controller.canChangeOwner}} @canMergePosts={{@controller.canMergePosts}} @toggleMultiSelect={{action "toggleMultiSelect"}} @mergePosts={{action "mergePosts"}} @deleteSelected={{action "deleteSelected"}} @deselectAll={{action "deselectAll"}} @selectAll={{action "selectAll"}} />
                </div>
              {{/if}}

            {{/if}}
          </ConditionalLoadingSpinner>

          <PluginOutlet @name="topic-area-bottom" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
        </section>
      </div>

    </div>
    {{#if @controller.loadedAllPosts}}
      {{#if @controller.session.showSignupCta}}
        {{!-- replace "Log In to Reply" with the infobox --}}
        <SignupCta />
      {{else}}
        {{#if @controller.currentUser}}
          <span>
            <PluginOutlet @name="topic-above-footer-buttons" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
          </span>

          <TopicFooterButtons @topic={{@controller.model}} @toggleMultiSelect={{action "toggleMultiSelect"}} @showTopicSlowModeUpdate={{routeAction "showTopicSlowModeUpdate"}} @deleteTopic={{action "deleteTopic"}} @recoverTopic={{action "recoverTopic"}} @toggleClosed={{action "toggleClosed"}} @toggleArchived={{action "toggleArchived"}} @toggleVisibility={{action "toggleVisibility"}} @showTopicTimerModal={{routeAction "showTopicTimerModal"}} @showFeatureTopic={{routeAction "showFeatureTopic"}} @showChangeTimestamp={{routeAction "showChangeTimestamp"}} @resetBumpDate={{action "resetBumpDate"}} @convertToPublicTopic={{action "convertToPublicTopic"}} @convertToPrivateMessage={{action "convertToPrivateMessage"}} @toggleBookmark={{action "toggleBookmark"}} @showFlagTopic={{routeAction "showFlagTopic"}} @toggleArchiveMessage={{action "toggleArchiveMessage"}} @editFirstPost={{action "editFirstPost"}} @deferTopic={{action "deferTopic"}} @replyToPost={{action "replyToPost"}} />
        {{else}}
          <AnonymousTopicFooterButtons @topic={{@controller.model}} />
        {{/if}}
      {{/if}}

      <br />

      <span>
        <PluginOutlet @name="topic-above-suggested" @connectorTagName="div" @outletArgs={{hash model=@controller.model}} />
      </span>

      <MoreTopics @topic={{@controller.model}} />
      <PluginOutlet @name="topic-below-suggested" @outletArgs={{hash model=@controller.model}} />
    {{/if}}
  {{else}}
    <div class="container">
      <ConditionalLoadingSpinner @condition={{@controller.noErrorYet}}>
        {{#if @controller.model.errorHtml}}
          <div class="not-found">{{htmlSafe @controller.model.errorHtml}}</div>
        {{else}}
          <div class="topic-error">
            <div>{{@controller.model.errorMessage}}</div>
            {{#if @controller.model.noRetry}}
              {{#unless @controller.currentUser}}
                <DButton @action={{routeAction "showLogin"}} @icon="user" @label="log_in" class="btn-primary topic-retry" />
              {{/unless}}
            {{else}}
              <DButton @action={{action "retryLoading"}} @icon="arrows-rotate" @label="errors.buttons.again" class="btn-primary topic-retry" />
            {{/if}}
          </div>
          <ConditionalLoadingSpinner @condition={{@controller.retrying}} />
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  {{/if}}

  {{#each (array @controller.model) as |topic|}}
    <PostTextSelection @quoteState={{@controller.quoteState}} @selectText={{action "selectText"}} @buildQuoteMarkdown={{@controller.buildQuoteMarkdown}} @editPost={{action "editPost"}} @topic={{topic}} />
  {{/each}}
</DiscourseTopic></template>)