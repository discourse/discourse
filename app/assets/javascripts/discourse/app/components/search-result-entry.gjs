import Component from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
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
import avatar from "discourse/helpers/avatar";
import categoryLink from "discourse/helpers/category-link";
import icon from "discourse/helpers/d-icon";
import discourseTags from "discourse/helpers/discourse-tags";
import formatDate from "discourse/helpers/format-date";
import lazyHash from "discourse/helpers/lazy-hash";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";

@tagName("div")
@classNames("fps-result")
@classNameBindings("bulkSelectEnabled")
@attributeBindings("role")
export default class SearchResultEntry extends Component {
  role = "listitem";

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
        <a href={{this.post.userPath}} data-user-card={{this.post.username}}>
          {{avatar this.post imageSize="large"}}
        </a>
      </div>

    </PluginOutlet>

    <div class="fps-topic" data-topic-id={{this.post.topic.id}}>
      <div class="topic">

        {{#if this.bulkSelectEnabled}}
          <TrackSelected
            @selectedList={{this.selected}}
            @selectedId={{this.post.topic}}
            class="bulk-select"
          />
        {{/if}}

        <a
          href={{this.post.url}}
          {{on "click" (fn this.logClick this.post.topic_id)}}
          class="search-link{{if this.post.topic.visited ' visited'}}"
          role="heading"
          aria-level="2"
        >
          <TopicStatus
            @topic={{this.post.topic}}
            @disableActions={{true}}
            @showPrivateMessageIcon={{true}}
          />

          <span class="topic-title">
            {{#if this.post.useTopicTitleHeadline}}
              {{htmlSafe this.post.topicTitleHeadline}}
            {{else}}
              <HighlightSearch @highlight={{this.highlightQuery}}>
                {{htmlSafe this.post.topic.fancyTitle}}
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
            {{categoryLink this.post.topic.category.parentCategory}}
          {{/if}}
          {{categoryLink this.post.topic.category hideParent=true}}
          {{#if this.post.topic}}
            {{discourseTags this.post.topic}}
          {{/if}}
          <span>
            <PluginOutlet
              @name="full-page-search-category"
              @connectorTagName="div"
              @outletArgs={{lazyHash post=this.post}}
            />
          </span>
        </div>
      </div>

      <PluginOutlet
        @name="search-result-entry-blurb-wrapper"
        @outletArgs={{lazyHash post=this.post logClick=this.logClick}}
      >
        <div class="blurb container">
          <span class="date">
            {{formatDate this.post.created_at format="tiny"}}
            {{#if this.post.blurb}}
              <span class="separator">-</span>
            {{/if}}
          </span>

          {{#if this.post.blurb}}
            {{#if this.siteSettings.use_pg_headlines_for_excerpt}}
              {{htmlSafe this.post.blurb}}
            {{else}}
              <HighlightSearch @highlight={{this.highlightQuery}}>
                {{htmlSafe this.post.blurb}}
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
              {{icon "heart"}}
            </span>
          {{/if}}
        {{/if}}
      </PluginOutlet>
    </div>

    <PluginOutlet @name="after-search-result-entry" />
  </template>
}
