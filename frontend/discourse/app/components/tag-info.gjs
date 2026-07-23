import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import renderTags from "discourse/lib/render-tags";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";

function tagGroupsInfo(tagInfo) {
  return i18n("tagging.tag_groups_info", {
    count: tagInfo?.tag_group_names?.length,
    tag_groups: tagInfo?.tag_group_names?.join(", "),
  });
}

function categoriesInfo(tagInfo) {
  const categories = tagInfo?.categories || [];
  return i18n("tagging.category_restrictions", {
    count: categories.length,
    categories: categories.map((c) => categoryBadgeHTML(c)).join(" "),
  });
}

function synonymsDescription(tagInfo) {
  const synonyms = tagInfo?.synonyms || [];
  return i18n("tagging.synonyms_description", {
    count: synonyms.length,
    base_tag_name: renderTags(null, { tags: [tagInfo] }),
    synonyms: renderTags(null, { tags: synonyms }),
  });
}

function nothingToShow(tagInfo) {
  return (
    isEmpty(tagInfo?.tag_group_names) &&
    isEmpty(tagInfo?.categories) &&
    isEmpty(tagInfo?.synonyms) &&
    !tagInfo?.category_restricted
  );
}

const TagInfo = <template>
  {{#if @tagInfo}}
    <section class="tag-info discovery-heading {{if @loading '--loading'}}">
      <div class="tag-name">
        <div class="tag-name-wrapper">
          {{dDiscourseTag @tagInfo}}
        </div>
        {{#if @tagInfo.description_cooked}}
          <div class="tag-description-wrapper">
            <div class="cooked">{{trustHTML @tagInfo.description_cooked}}</div>
          </div>
        {{/if}}
      </div>

      <p class="tag-associations">
        {{#if @tagInfo.tag_group_names}}
          <span>{{tagGroupsInfo @tagInfo}}</span>
        {{/if}}
        {{#if @tagInfo.categories}}
          <span>{{trustHTML (categoriesInfo @tagInfo)}}</span>
        {{else if @tagInfo.category_restricted}}
          <span>{{i18n "tagging.category_restricted"}}</span>
        {{/if}}
        {{#if (nothingToShow @tagInfo)}}
          {{trustHTML (i18n "tagging.default_info")}}
          {{#if @currentUser.staff}}
            {{trustHTML (i18n "tagging.staff_info" basePath=(dBasePath))}}
          {{/if}}
        {{/if}}
      </p>

      {{#if @tagInfo.synonyms}}
        <div class="synonyms-list">{{trustHTML
            (synonymsDescription @tagInfo)
          }}</div>
      {{/if}}

      {{#if @currentUser.canEditTags}}
        <PluginOutlet
          @name="tag-custom-settings"
          @outletArgs={{lazyHash tag=@tagInfo}}
          @connectorTagName="section"
        />
      {{/if}}
    </section>
  {{/if}}
</template>;

export default TagInfo;
