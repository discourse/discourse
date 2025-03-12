import Component from "@ember/component";
import { sort } from "@ember/object/computed";
import { classNameBindings } from "@ember-decorators/component";
import CategoryTitleLink from "discourse/components/category-title-link";
import icon from "discourse/helpers/d-icon";
import discourseTag from "discourse/helpers/discourse-tag";
import discourseComputed from "discourse/lib/decorators";
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

  @discourseComputed("titleKey")
  title(titleKey) {
    return titleKey && i18n(titleKey);
  }

  @discourseComputed("categoryId")
  category(categoryId) {
    return categoryId && Category.findById(categoryId);
  }

  @discourseComputed("category.fullSlug")
  categoryClass(slug) {
    return slug && `tag-list-${slug}`;
  }

  @discourseComputed("tagGroupName")
  tagGroupNameClass(groupName) {
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
