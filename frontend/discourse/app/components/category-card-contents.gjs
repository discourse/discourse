import { trustHTML } from "@ember/template";
import { classNameBindings, classNames } from "@ember-decorators/component";
import CardContentsBase from "discourse/components/card-contents-base";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const CATEGORY_HASHTAG_SELECTOR =
  'a.hashtag-cooked[data-type="category"][data-id]';

@classNames("category-card")
@classNameBindings("visible:show")
export default class CategoryCardContents extends CardContentsBase {
  avatarDataAttrKey = "id";
  avatarSelector = CATEGORY_HASHTAG_SELECTOR;
  canShowWhenUserProfilesHidden = true;
  category = null;
  categoryId = null;
  elementId = "category-card";
  eventPrefix = null;
  menuIdentifier = "category-card";
  mentionSelector = CATEGORY_HASHTAG_SELECTOR;
  showCardBeforeLoad = false;
  triggeringLinkSelector = CATEGORY_HASHTAG_SELECTOR;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.appEvents.on("dom:clean", this, this._close);
  }

  willDestroyElement() {
    this.appEvents.off("dom:clean", this, this._close);
    super.willDestroyElement(...arguments);
  }

  _close() {
    this.setProperties({ category: null, categoryId: null });
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
      <div class="card-content category-card-content">
        <h2 class="category-card-content__title">
          {{this.category.name}}
          {{#if this.category.read_restricted}}
            <span class="category-card-content__private">{{dIcon "lock"}}</span>
          {{/if}}
        </h2>
        {{#if this.category.parentCategory}}
          <div class="parent-category">
            {{dCategoryLink this.category.parentCategory}}
          </div>
        {{/if}}
        <p class="category-card-content__description">
          {{trustHTML this.category.description}}
        </p>
        <div class="category-card-content__types">
          {{#each-in this.category.category_types as |typeId type|}}
            <span class="category-card-content__type">{{type.name}}</span>
          {{/each-in}}
        </div>
      </div>
    {{/if}}
  </template>
}
