/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import CategoryTitleLink from "discourse/components/category-title-link";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import { arraySortedByProperties } from "discourse/lib/array-tools";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

@tagName("")
export default class TagList extends Component {
  isPrivateMessage = false;

  @computed("tags", "sortProperties")
  get sortedTags() {
    return arraySortedByProperties(this.tags, this.sortProperties);
  }

  @computed("titleKey")
  get title() {
    return this.titleKey && i18n(this.titleKey);
  }

  @computed("categoryId")
  get category() {
    return this.categoryId && Category.findById(this.categoryId);
  }

  @computed("category.fullSlug")
  get categoryClass() {
    return this.category?.fullSlug && `tag-list-${this.category?.fullSlug}`;
  }

  @computed("tagGroupName")
  get tagGroupNameClass() {
    if (this.tagGroupName) {
      const groupName = this.tagGroupName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return groupName && `tag-group-${groupName}`;
    }
  }

  <template>
    <div
      class={{concatClass
        "tags-list"
        "tag-list"
        this.categoryClass
        this.tagGroupNameClass
      }}
      ...attributes
    >
      {{#if this.title}}
        <h3>{{this.title}}</h3>
      {{/if}}
      {{#if this.category}}
        <CategoryTitleLink @category={{this.category}} />
      {{/if}}
      {{#if this.tagGroupName}}
        <h3>{{this.tagGroupName}}</h3>
      {{/if}}
      {{#each this.sortedTags as |tag|}}
        <div class="tag-box">
          {{discourseTag
            tag
            description=tag.description
            isPrivateMessage=this.isPrivateMessage
            pmOnly=tag.pmOnly
            tagsForUser=this.tagsForUser
          }}
          {{#if tag.pmOnly}}
            {{icon "envelope"}}
          {{/if}}
          {{#if tag.totalCount}}
            <span class="tag-count">
              x
              {{tag.totalCount}}
            </span>
          {{/if}}
        </div>
      {{/each}}
      <div class="clearfix"></div>
    </div>
  </template>
}
