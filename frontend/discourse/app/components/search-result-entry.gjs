import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import HighlightSearch from "discourse/components/highlight-search";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicStatus from "discourse/components/topic-status";
import TrackSelected from "discourse/components/track-selected";
import lazyHash from "discourse/helpers/lazy-hash";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { logSearchLinkClick } from "discourse/lib/search";
import { applyValueTransformer } from "discourse/lib/transformer";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class SearchResultEntry extends Component {
  @service siteSettings;

  get shouldShowPrivateMessageIcon() {
    // Only show PM icon if this is a PM AND we're not in a PM-only search
    return this.args.post.topic.isPrivateMessage && !this.args.isPMOnly;
  }

  get additionalClasses() {
    return applyValueTransformer("search-result-entry-class", [], {
      post: this.args.post,
    });
  }

  @action
  logClick(topicId, event) {
    // Avoid click logging when any modifier keys are pressed.
    if (wantsNewWindow(event)) {
      return;
    }

    if (this.args.searchLogId && topicId) {
      logSearchLinkClick({
        searchLogId: this.args.searchLogId,
        searchResultId: topicId,
        searchResultType: "topic",
      });
    }
  }

  <template>
    <div
      role="listitem"
      ...attributes
      class={{dConcatClass
        "fps-result"
        (if @bulkSelectEnabled "bulk-select-enabled")
        this.additionalClasses
      }}
    >
      <PluginOutlet
        @name="search-results-topic-avatar-wrapper"
        @outletArgs={{lazyHash post=@post}}
      >
        <div class="author">
          <a data-user-card={{@post.username}} href={{@post.userPath}}>
            {{dAvatar @post imageSize="large"}}
          </a>
        </div>

      </PluginOutlet>

      <div class="fps-topic" data-topic-id={{@post.topic.id}}>
        <div class="topic">

          {{#if @bulkSelectEnabled}}
            <TrackSelected
              class="bulk-select"
              @selectedId={{@post}}
              @selectedList={{@selected}}
            />
          {{/if}}

          <a
            aria-level="2"
            class="search-link{{if @post.topic.visited ' visited'}}"
            href={{@post.url}}
            role="heading"
            {{on "click" (fn this.logClick @post.topic_id)}}
          >
            <TopicStatus
              @disableActions={{true}}
              @showPrivateMessageIcon={{this.shouldShowPrivateMessageIcon}}
              @topic={{@post.topic}}
            />

            <span class="topic-title">
              {{#if @post.useTopicTitleHeadline}}
                {{trustHTML @post.topicTitleHeadline}}
              {{else}}
                <HighlightSearch @highlight={{@highlightQuery}}>
                  {{trustHTML @post.topic.fancyTitle}}
                </HighlightSearch>
              {{/if}}
            </span>
            <PluginOutlet
              @name="search-results-topic-title-suffix"
              @outletArgs={{lazyHash topic=@post.topic}}
            />
          </a>

          <div class="search-category">
            {{#if @post.topic.category.parentCategory}}
              {{dCategoryLink @post.topic.category.parentCategory}}
            {{/if}}
            {{dCategoryLink @post.topic.category hideParent=true}}
            {{#if @post.topic}}
              <PluginOutlet
                @name="search-result-entry-tags-wrapper"
                @outletArgs={{lazyHash
                  post=@post
                  topic=@post.topic
                  tags=@post.topic.tags
                }}
              >
                {{dDiscourseTags @post.topic}}
              </PluginOutlet>
            {{/if}}
            <span>
              <PluginOutlet
                @connectorTagName="div"
                @name="full-page-search-category"
                @outletArgs={{lazyHash post=@post}}
              />
            </span>
          </div>
        </div>

        <PluginOutlet
          @name="search-result-entry-blurb-wrapper"
          @outletArgs={{lazyHash
            post=@post
            logClick=this.logClick
            highlightQuery=@highlightQuery
          }}
        >
          <div class="blurb container">
            <span class="date">
              {{dFormatDate @post.created_at format="tiny"}}
              {{#if @post.blurb}}
                <span class="separator">-</span>
              {{/if}}
            </span>

            {{#if @post.blurb}}
              {{#if this.siteSettings.use_pg_headlines_for_excerpt}}
                {{trustHTML @post.blurb}}
              {{else}}
                <HighlightSearch @highlight={{@highlightQuery}}>
                  {{trustHTML @post.blurb}}
                </HighlightSearch>
              {{/if}}
            {{/if}}
          </div>
        </PluginOutlet>

        <PluginOutlet
          @name="search-result-entry-stats-wrapper"
          @outletArgs={{lazyHash post=@post}}
        >
          {{#if @showLikeCount}}
            {{#if @post.like_count}}
              <span class="like-count">
                <span class="value">{{@post.like_count}}</span>
                {{dIcon "heart"}}
              </span>
            {{/if}}
          {{/if}}
        </PluginOutlet>
      </div>

      <PluginOutlet
        @name="after-search-result-entry"
        @outletArgs={{lazyHash post=@post}}
      />
    </div>
  </template>
}
