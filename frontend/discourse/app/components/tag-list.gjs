import Component from "@glimmer/component";
import CategoryTitleLink from "discourse/components/category-title-link";
import { arraySortedByProperties } from "discourse/lib/array-tools";
import { slugify } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class TagList extends Component {
  get isPrivateMessage() {
    return this.args.isPrivateMessage ?? false;
  }

  get sortedTags() {
    return arraySortedByProperties(this.args.tags, this.args.sortProperties);
  }

  get title() {
    return this.args.titleKey && i18n(this.args.titleKey);
  }

  get category() {
    return this.args.categoryId && Category.findById(this.args.categoryId);
  }

  get categoryClass() {
    return this.category?.fullSlug && `tag-list-${this.category?.fullSlug}`;
  }

  get tagGroupNameSlug() {
    if (this.args.tagGroupName) {
      return slugify(this.args.tagGroupName);
    }
  }

  get tagGroupNameClass() {
    return this.tagGroupNameSlug && `tag-group-${this.tagGroupNameSlug}`;
  }

  <template>
    <div
      class={{dConcatClass
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
      {{#if @tagGroupName}}
        <h3 id={{this.tagGroupNameSlug}}><a
            aria-label={{i18n "post.heading_anchor"}}
            class="anchor"
            href="#{{this.tagGroupNameSlug}}"
          ></a>{{@tagGroupName}}</h3>
      {{/if}}
      {{#each this.sortedTags as |tag|}}
        <div class="tag-box">
          {{dDiscourseTag
            tag
            description=tag.description
            isPrivateMessage=this.isPrivateMessage
            pmOnly=tag.pmOnly
            tagsForUser=@tagsForUser
          }}
          {{#if tag.pmOnly}}
            {{dIcon "envelope"}}
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
