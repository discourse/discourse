/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { sort } from "@ember/object/computed";
import { classNameBindings } from "@ember-decorators/component";
import CategoryTitleLink from "discourse/components/category-title-link";
import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

@classNameBindings(
  ":tags-list",
  ":tag-list",
  "categoryClass",
  "tagGroupNameClass"
)
export default class TagList extends Component {
  isPrivateMessage = false;

  @sort("tags", "sortProperties") sortedTags;

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
    let groupName = this.tagGroupName;
    if (groupName) {
      groupName = groupName
        .replace(/\s+/g, "-")
        .replace(/[!\"#$%&'\(\)\*\+,\.\/:;<=>\?\@\[\\\]\^`\{\|\}~]/g, "")
        .toLowerCase();
      return groupName && `tag-group-${groupName}`;
    }
  }

  <template>
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
          tag.id
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
  </template>
}
