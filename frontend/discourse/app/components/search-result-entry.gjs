/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import HighlightSearch from "discourse/components/highlight-search";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicStatus from "discourse/components/topic-status";
import TrackSelected from "discourse/components/track-selected";
import lazyHash from "discourse/helpers/lazy-hash";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@tagName("div")
@classNames("fps-result")
@classNameBindings("bulkSelectEnabled")
@attributeBindings("role")
export default class SearchResultEntry extends Component {
  role = "listitem";

  get shouldShowPrivateMessageIcon() {
    // Only show PM icon if this is a PM AND we're not in a PM-only search
    return this.post.topic.isPrivateMessage && !this.isPMOnly;
  }

  @action
  logClick(topicId, event) {
    // Avoid click logging when any modifier keys are pressed.
    if (wantsNewWindow(event)) {
      return;
    }

    if (this.searchLogId && topicId) {
      logSearchLinkClick({
        searchLogId: this.searchLogId,
        searchResultId: topicId,
        searchResultType: "topic",
      });
    }
  }

  <template>
    <PluginOutlet
      @name="search-results-topic-avatar-wrapper"
      @outletArgs={{lazyHash post=this.post}}
    >
      <div class="author">
        <a data-user-card={{this.post.username}} href={{this.post.userPath}}>
          {{dAvatar this.post imageSize="large"}}
        </a>
      </div>

    </PluginOutlet>

    <div class="fps-topic" data-topic-id={{this.post.topic.id}}>
      <div class="topic">

        {{#if this.bulkSelectEnabled}}
          <TrackSelected
            class="bulk-select"
            @selectedId={{this.post}}
            @selectedList={{this.selected}}
          />
        {{/if}}

        <a
          aria-level="2"
          class="search-link{{if this.post.topic.visited ' visited'}}"
          href={{this.post.url}}
          role="heading"
          {{on "click" (fn this.logClick this.post.topic_id)}}
        >
          <TopicStatus
            @disableActions={{true}}
            @showPrivateMessageIcon={{this.shouldShowPrivateMessageIcon}}
            @topic={{this.post.topic}}
          />

          <span class="topic-title">
            {{#if this.post.useTopicTitleHeadline}}
              {{trustHTML this.post.topicTitleHeadline}}
            {{else}}
              <HighlightSearch @highlight={{this.highlightQuery}}>
                {{trustHTML this.post.topic.fancyTitle}}
              </HighlightSearch>
            {{/if}}
          </span>
          <PluginOutlet
            @name="search-results-topic-title-suffix"
            @outletArgs={{lazyHash topic=this.post.topic}}
          />
        </a>

        <div class="search-category">
          {{#if this.post.topic.category.parentCategory}}
            {{dCategoryLink this.post.topic.category.parentCategory}}
          {{/if}}
          {{dCategoryLink this.post.topic.category hideParent=true}}
          {{#if this.post.topic}}
            {{dDiscourseTags this.post.topic}}
          {{/if}}
          <span>
            <PluginOutlet
              @connectorTagName="div"
              @name="full-page-search-category"
              @outletArgs={{lazyHash post=this.post}}
            />
          </span>
        </div>
      </div>

      <PluginOutlet
        @name="search-result-entry-blurb-wrapper"
        @outletArgs={{lazyHash
          post=this.post
          logClick=this.logClick
          highlightQuery=this.highlightQuery
        }}
      >
        <div class="blurb container">
          <span class="date">
            {{dFormatDate this.post.created_at format="tiny"}}
            {{#if this.post.blurb}}
              <span class="separator">-</span>
            {{/if}}
          </span>

          {{#if this.post.blurb}}
            {{#if this.siteSettings.use_pg_headlines_for_excerpt}}
              {{trustHTML this.post.blurb}}
            {{else}}
              <HighlightSearch @highlight={{this.highlightQuery}}>
                {{trustHTML this.post.blurb}}
              </HighlightSearch>
            {{/if}}
          {{/if}}
        </div>
      </PluginOutlet>

      <PluginOutlet
        @name="search-result-entry-stats-wrapper"
        @outletArgs={{lazyHash post=this.post}}
      >
        {{#if this.showLikeCount}}
          {{#if this.post.like_count}}
            <span class="like-count">
              <span class="value">{{this.post.like_count}}</span>
              {{dIcon "heart"}}
            </span>
          {{/if}}
        {{/if}}
      </PluginOutlet>
    </div>

    <PluginOutlet @name="after-search-result-entry" />
  </template>
}
