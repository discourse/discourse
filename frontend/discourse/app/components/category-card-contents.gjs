import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { classNameBindings, classNames } from "@ember-decorators/component";
import CardContentsBase from "discourse/components/card-contents-base";
import CategoryLogo from "discourse/components/category-logo";
import FeaturedTopic from "discourse/components/topic-list/featured-topic";
import categoryVariables from "discourse/helpers/category-variables";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import Topic from "discourse/models/topic";
import { and, eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

const CATEGORY_HASHTAG_SELECTOR =
  'a.hashtag-cooked[data-type="category"][data-id]';
const LATEST_TOPICS_COUNT = 3;
const LATEST_TOPICS_CACHE_MS = 5 * 60 * 1000;

const CategoryNameLink = <template>
  <a href={{@category.url}} class="category-card__link" ...attributes>
    <span
      class="category-card__style
        {{concat '--style-' (or @category.style_type 'square')}}"
      style={{categoryVariables @category}}
    >
      {{#if (and (eq @category.style_type "icon") @category.icon)}}
        {{dIcon @category.icon}}
      {{else if (and (eq @category.style_type "emoji") @category.emoji)}}
        {{dReplaceEmoji (concat ":" @category.emoji ":")}}
      {{/if}}
    </span>
    <span class="category-card__name">{{@category.name}}</span>
    {{yield}}
  </a>
</template>;

@classNames("category-card")
@classNameBindings("visible:show")
export default class CategoryCardContents extends CardContentsBase {
  @service composer;
  @service store;

  avatarDataAttrKey = "id";
  avatarSelector = CATEGORY_HASHTAG_SELECTOR;
  canShowWhenUserProfilesHidden = true;
  category = null;
  categoryId = null;
  elementId = "category-card";
  eventPrefix = null;
  latestTopics = null;
  menuIdentifier = "category-card";
  mentionSelector = CATEGORY_HASHTAG_SELECTOR;
  showCardBeforeLoad = false;
  triggeringLinkSelector = CATEGORY_HASHTAG_SELECTOR;

  #latestTopicsCache = new Map();

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.appEvents.on("dom:clean", this, this._close);
  }

  willDestroyElement() {
    this.appEvents.off("dom:clean", this, this._close);
    super.willDestroyElement(...arguments);
  }

  @computed("category.permission")
  get canCreateTopic() {
    const canCreateTopic =
      !!this.currentUser?.can_create_topic && !!this.category?.canCreateTopic;

    return applyValueTransformer("can-create-topic-button", canCreateTopic, {
      category: this.category,
      tag: null,
      createTopicDisabled: !canCreateTopic,
    });
  }

  @computed("category.topic_url", "currentUser.admin")
  get canEditDescription() {
    return !!this.currentUser?.admin && !!this.category?.topic_url;
  }

  @computed("category")
  get createTopicIcon() {
    const defaultIcon = "far-pen-to-square";

    return applyValueTransformer("create-topic-icon", defaultIcon, {
      site: this.site,
      defaultIcon,
      category: this.category,
      currentUser: this.currentUser,
    });
  }

  @computed("category")
  get createTopicLabel() {
    const defaultKey = "topic.create";
    const isSharedDraftsCategory =
      !!this.site.shared_drafts_category_id &&
      this.category?.id === this.site.shared_drafts_category_id;

    return applyValueTransformer(
      "create-topic-label",
      isSharedDraftsCategory ? "topic.create_shared_draft" : defaultKey,
      {
        site: this.site,
        defaultKey,
        category: this.category,
        currentUser: this.currentUser,
      }
    );
  }

  @action
  createTopic() {
    this.composer.openNewTopic({ category: this.category });
    this._close();
  }

  @action
  async editDescription(event) {
    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    const topicUrl = this.category.topic_url;
    this._close();

    try {
      const topicJson = await ajax(`${topicUrl}.json`);
      const topic = Topic.create(topicJson);
      const post = this.store.createRecord("post", {
        ...topicJson.post_stream.posts[0],
        topic,
      });

      this.composer.open({
        action: Composer.EDIT,
        post,
        draftKey: topic.draft_key,
        draftSequence: topic.draft_sequence,
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #loadLatestTopics(category) {
    const cached = this.#latestTopicsCache.get(category.id);
    let topics = cached?.topics;

    if (!cached || Date.now() - cached.fetchedAt > LATEST_TOPICS_CACHE_MS) {
      try {
        const aboutTopicId = Number(category.topic_url?.split("/").pop());
        const list = await this.store.findFiltered("topicList", {
          filter: `${category.path.slice(1)}/l/latest`,
          params: { per_page: LATEST_TOPICS_COUNT + 1 },
        });

        topics = list.topics
          .filter((topic) => topic.id !== aboutTopicId)
          .slice(0, LATEST_TOPICS_COUNT);

        this.#latestTopicsCache.set(category.id, {
          topics,
          fetchedAt: Date.now(),
        });
      } catch {
        topics = [];
      }
    }

    if (!this.isDestroying && !this.isDestroyed && this.category === category) {
      this.set("latestTopics", topics);
    }
  }

  _close() {
    this.setProperties({
      category: null,
      categoryId: null,
      latestTopics: null,
    });
    super._close(...arguments);
  }

  async _showCallback(categoryId) {
    const target = this.cardTarget;
    this.setProperties({ categoryId, loading: true });

    try {
      const category = await Category.asyncFindById(categoryId);

      if (
        this.isDestroying ||
        this.isDestroyed ||
        this.categoryId !== categoryId ||
        this.cardTarget !== target
      ) {
        return;
      }

      if (!category) {
        this._close();
        DiscourseURL.routeTo(target.href);
        return;
      }

      this.setProperties({ category, loading: null, visible: true });
      this.#loadLatestTopics(category);
      return category;
    } catch {
      if (
        !this.isDestroying &&
        !this.isDestroyed &&
        this.categoryId === categoryId &&
        this.cardTarget === target
      ) {
        this._close();
        DiscourseURL.routeTo(target.href);
      }
    }
  }

  <template>
    {{#if this.visible}}
      <div class="card-content">
        <div class="card-row first-row">
          {{#if this.category.uploaded_logo.url}}
            <a
              href={{this.category.url}}
              class="category-card__avatar"
              tabindex="-1"
              aria-hidden="true"
            >
              <CategoryLogo @category={{this.category}} />
            </a>
          {{/if}}
          <div class="names">
            {{#if this.category.parentCategory}}
              <div class="category-card__parent">
                <CategoryNameLink @category={{this.category.parentCategory}} />
              </div>
            {{/if}}
            <div class="names__primary">
              <CategoryNameLink @category={{this.category}}>
                {{#if this.category.read_restricted}}
                  {{dIcon "lock"}}
                {{/if}}
              </CategoryNameLink>
            </div>
          </div>
          {{#if this.canCreateTopic}}
            <ul class="usercard-controls">
              <li>
                <DButton
                  class="btn-primary category-card__new-topic"
                  @action={{this.createTopic}}
                  @icon={{this.createTopicIcon}}
                  @label={{this.createTopicLabel}}
                />
              </li>
            </ul>
          {{/if}}
        </div>

        {{#if (or this.category.description this.canEditDescription)}}
          <div class="card-row second-row">
            {{#if this.category.description}}
              <div class="bio">
                {{trustHTML this.category.description}}
              </div>
            {{/if}}
            {{#if this.canEditDescription}}
              <a
                href={{this.category.topic_url}}
                class="category-card__edit-description"
                {{on "click" this.editDescription}}
              >
                {{dIcon "pencil"}}
                {{i18n "category.change_in_category_topic"}}
              </a>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.latestTopics}}
          <div class="card-row category-card__latest">
            <div class="category-card__latest-title">
              {{i18n "category.latest_topics"}}
            </div>
            <ul class="category-card__topics">
              {{#each this.latestTopics as |topic|}}
                <li><FeaturedTopic @topic={{topic}} /></li>
              {{/each}}
            </ul>
          </div>
        {{else if (eq this.latestTopics null)}}
          <DSkeleton class="card-row category-card__latest" @count={{3}} />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
