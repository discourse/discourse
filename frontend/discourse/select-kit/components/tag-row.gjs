import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";

@classNames("tag-row")
export default class TagRow extends SelectKitRowComponent {
  @computed("item")
  get isTag() {
    return this.item.id !== "no-tags" && this.item.id !== "all-tags";
  }

  <template>
    {{#if this.isTag}}
      {{dDiscourseTag
        this.rowName
        noHref=true
        description=this.item.description
        count=this.item.count
      }}
      {{#if this.rowDisabled}}
        <span class="disabled-reason">{{this.title}}</span>
      {{else if this.item.target_tag}}
        <span class="synonym-hint">
          {{i18n "tagging.synonym_hint" tag_name=this.item.target_tag.name}}
        </span>
      {{/if}}
    {{else}}
      <span class="name">{{this.rowName}}</span>
    {{/if}}
  </template>
}
