import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import TopicMapLink from "discourse/components/topic-map/topic-map-link";
import TopicParticipants from "discourse/components/topic-map/topic-participants";
import TopicViews from "discourse/components/topic-map/topic-views";
import TopicViewsChart from "discourse/components/topic-map/topic-views-chart";
import avatar from "discourse/helpers/bound-avatar-template";
import number from "discourse/helpers/number";
import slice from "discourse/helpers/slice";
import { ajax } from "discourse/lib/ajax";
import { emojiUnescape } from "discourse/lib/text";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";
import and from "truth-helpers/helpers/and";
import lt from "truth-helpers/helpers/lt";
import not from "truth-helpers/helpers/not";

const TRUNCATED_LINKS_LIMIT = 5;
const MIN_POST_READ_TIME = 4;

export default class SimpleTopicMapSummary extends Component {
  @service site;
  @service siteSettings;
  @service mapCache;

  @tracked allLinksShown = false;
  @tracked mostLikedPosts = [];
  @tracked views = [];
  @tracked loading = true;

  get shouldShowParticipants() {
    return (
      this.args.topic.posts_count >= 10 &&
      this.args.topicDetails.participants?.length >= 2 &&
      !this.site.mobileView
    );
  }

  get readTime() {
    const calculatedTime = Math.ceil(
      Math.max(
        this.args.topic.word_count / this.siteSettings.read_time_word_count,
        (this.args.topic.posts_count * MIN_POST_READ_TIME) / 60
      )
    );

    return calculatedTime > 3 ? calculatedTime : null;
  }

  get topRepliesSummaryEnabled() {
    return this.args.postStream.summary;
  }

  get topRepliesTitle() {
    if (this.topRepliesSummaryEnabled) {
      return;
    }

    return I18n.t("summary.short_title");
  }

  get topRepliesIcon() {
    return this.topRepliesSummaryEnabled ? "arrows-alt-v" : "layer-group";
  }

  get topRepliesLabel() {
    return this.topRepliesSummaryEnabled
      ? I18n.t("summary.show_all_label")
      : I18n.t("summary.short_label");
  }

  get loneStat() {
    const hasViews = this.args.topic.views >= 0;
    const hasLikes =
      this.args.topic.like_count > 5 && this.args.topic.posts_count > 10;
    const hasLinks = this.linksCount > 0;
    const hasUsers = this.args.topic.participant_count > 5;
    const canSummarize = this.args.topic.has_summary;

    if (canSummarize) {
      return false;
    }

    return (
      [hasViews, hasLikes, hasLinks, hasUsers].filter(Boolean).length === 1
    );
  }

  get linksCount() {
    return this.args.topicDetails.links?.length ?? 0;
  }

  get topicLinks() {
    return this.args.topicDetails.links;
  }

  get linksToShow() {
    return this.allLinksShown
      ? this.topicLinks
      : this.topicLinks.slice(0, TRUNCATED_LINKS_LIMIT);
  }

  @action
  showAllLinks() {
    this.allLinksShown = true;
  }

  @action
  showTopReplies() {
    this.args.postStream.showTopReplies();
  }

  @action
  cancelFilter() {
    this.args.postStream.cancelFilter();
    this.args.postStream.refresh();
  }

  @action
  fetchMostLiked() {
    const cacheKey = `mostLikedPosts_${this.args.topic.id}`;
    const cachedData = this.mapCache.get(cacheKey);
    this.loading = true;

    if (cachedData) {
      this.mostLikedPosts = cachedData;
      this.loading = false;
      return;
    }

    const filter = `/search.json?q=" " topic%3A${this.args.topic.id} order%3Alikes`;

    ajax(filter)
      .then((data) => {
        data.posts.sort((a, b) => b.like_count - a.like_count);
        const mostLikedPosts = data.posts
          .filter((post) => post.post_number !== 1 && post.like_count !== 0)
          .slice(0, 3);

        this.mapCache.set(cacheKey, mostLikedPosts);
        this.mostLikedPosts = mostLikedPosts;
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error("Error fetching posts:", error);
      })
      .finally(() => {
        this.loading = false;
      });
  }

  @action
  fetchViews() {
    const cacheKey = `topicViews_${this.args.topic.id}`;
    const cachedData = this.mapCache.get(cacheKey);
    this.loading = true;

    if (cachedData) {
      this.views = cachedData;
      this.loading = false;
      return;
    }

    ajax(`/t/${this.args.topic.id}/view-stats.json`)
      .then((data) => {
        if (data.stats.length) {
          this.views = data;
        } else {
          data.stats.push({
            viewed_at: new Date().toISOString().split("T")[0],
            views: this.args.topic.views,
          });
          this.views = data;
        }
        this.mapCache.set(cacheKey, data);
      })
      .catch((error) => {
        // eslint-disable-next-line no-console
        console.error("Error fetching views:", error);
      })
      .finally(() => {
        this.loading = false;
      });
  }

  <template>
    <ul class={{if this.loneStat "--single-stat"}}>
      <DMenu
        @arrow={{true}}
        @identifier="map-views"
        @interactive={{true}}
        @triggers="click"
        @modalForMobile={{true}}
        @placement="right"
        @groupIdentifier="topic-map"
        @inline={{true}}
        @onShow={{this.fetchViews}}
      >
        <:trigger>
          {{number @topic.views noTitle="true"}}
          <span role="presentation">{{i18n
              "views_lowercase"
              count=@topic.views
            }}</span>
        </:trigger>
        <:content>
          <section class="views topic-map-views">
            <h3>{{i18n "topic_map.menu_titles.views"}}</h3>
            <ConditionalLoadingSpinner @condition={{this.loading}}>
              {{#if (gt this.views.stats.length 2)}}
                <TopicViewsChart
                  @views={{this.views}}
                  @created={{@topic.created_at}}
                />
              {{else}}
                <TopicViews @views={{this.views}} />
              {{/if}}
            </ConditionalLoadingSpinner>
          </section>
        </:content>
      </DMenu>

      {{#if (and (gt @topic.like_count 5) (gt @topic.posts_count 10))}}
        <DMenu
          @arrow={{true}}
          @identifier="map-likes"
          @interactive={{true}}
          @triggers="click"
          @modalForMobile={{true}}
          @placement="right"
          @groupIdentifier="topic-map"
          @inline={{true}}
        >
          <:trigger>
            {{number @topic.like_count noTitle="true"}}
            <span role="presentation">{{i18n
                "likes_lowercase"
                count=@topic.like_count
              }}</span>
          </:trigger>
          <:content>
            <section class="likes" {{didInsert this.fetchMostLiked}}>
              <h3>{{i18n "topic_map.menu_titles.replies"}}</h3>
              <ConditionalLoadingSpinner @condition={{this.loading}}>
                <ul>
                  {{#each this.mostLikedPosts as |post|}}
                    <li>
                      <a
                        href="/t/{{@topic.slug}}/{{@topic.id}}/{{post.post_number}}"
                      >
                        <span class="like-section__user">
                          {{avatar
                            post.avatar_template
                            "tiny"
                            (hash title=post.username)
                          }}
                          {{post.username}}
                        </span>
                        <span class="like-section__likes">
                          {{post.like_count}}
                          {{dIcon "heart"}}</span>
                        <p>
                          {{htmlSafe (emojiUnescape post.blurb)}}
                        </p>
                      </a>
                    </li>
                  {{/each}}
                </ul>
              </ConditionalLoadingSpinner>
            </section>
          </:content>
        </DMenu>
      {{/if}}

      {{#if (gt this.linksCount 0)}}
        <DMenu
          @arrow={{true}}
          @identifier="map-links"
          @interactive={{true}}
          @triggers="click"
          @modalForMobile={{true}}
          @groupIdentifier="topic-map"
          @placement="right"
          @inline={{true}}
        >
          <:trigger>
            {{number this.linksCount noTitle="true"}}
            <span role="presentation">{{i18n
                "links_lowercase"
                count=this.linksCount
              }}</span>
          </:trigger>
          <:content>
            <section class="links">
              <h3>{{i18n "topic_map.links_title"}}</h3>
              <table class="topic-links">
                <tbody>
                  {{#each this.linksToShow as |link|}}
                    <tr>
                      <td>
                        <span
                          class="badge badge-notification clicks"
                          title={{i18n "topic_map.clicks" count=link.clicks}}
                        >
                          {{link.clicks}}
                        </span>
                      </td>
                      <td>
                        <TopicMapLink
                          @attachment={{link.attachment}}
                          @title={{link.title}}
                          @rootDomain={{link.root_domain}}
                          @url={{link.url}}
                          @userId={{link.user_id}}
                        />
                      </td>
                    </tr>
                  {{/each}}
                </tbody>
              </table>
              {{#if
                (and
                  (not this.allLinksShown)
                  (lt TRUNCATED_LINKS_LIMIT this.topicLinks.length)
                )
              }}
                <div class="link-summary">
                  <span>
                    <DButton
                      @action={{this.showAllLinks}}
                      @title="topic_map.links_shown"
                      @icon="chevron-down"
                      class="btn-flat"
                    />
                  </span>
                </div>
              {{/if}}
            </section>
          </:content>
        </DMenu>
      {{/if}}
      {{#if (gt @topic.participant_count 5)}}
        <DMenu
          @arrow={{true}}
          @identifier="map-users"
          @interactive={{true}}
          @triggers="click"
          @placement="right"
          @modalForMobile={{true}}
          @groupIdentifier="topic-map"
          @inline={{true}}
        >
          <:trigger>
            {{number @topic.participant_count noTitle="true"}}
            <span role="presentation">{{i18n
                "users_lowercase"
                count=@topic.participant_count
              }}</span>
          </:trigger>
          <:content>
            <section class="avatars">
              <TopicParticipants
                @title={{i18n "topic_map.participants_title"}}
                @userFilters={{@userFilters}}
                @participants={{@topicDetails.participants}}
              />
            </section>
          </:content>
        </DMenu>
      {{/if}}
      {{#if this.shouldShowParticipants}}
        <li class="avatars">
          <TopicParticipants
            @participants={{slice 0 5 @topicDetails.participants}}
            @userFilters={{@userFilters}}
          />
        </li>
      {{/if}}
      <div class="map-buttons">
        {{#if this.readTime}}
          <div class="estimated-read-time">
            <span> {{i18n "topic_map.read"}} </span>
            <span>
              {{this.readTime}}
              {{i18n "topic_map.minutes"}}
            </span>
          </div>
        {{/if}}
        <div class="summarization-buttons">
          {{#if @topic.has_summary}}
            <DButton
              @action={{if
                @postStream.summary
                this.cancelFilter
                this.showTopReplies
              }}
              @translatedTitle={{this.topRepliesTitle}}
              @translatedLabel={{this.topRepliesLabel}}
              @icon={{this.topRepliesIcon}}
              class="top-replies"
            />
          {{/if}}
        </div>
      </div>
    </ul>
  </template>
}
