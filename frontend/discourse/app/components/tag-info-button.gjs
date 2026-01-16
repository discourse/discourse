import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import discourseTags from "discourse/helpers/discourse-tags";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class TagInfoButton extends Component {
  @service store;
  @service router;

  @tracked tagInfo = null;
  @tracked loading = false;

  get canEditTags() {
    return this.args.currentUser?.canEditTags;
  }

  get hasSynonyms() {
    return this.tagInfo?.synonyms?.length > 0;
  }

  get showButton() {
    if (this.canEditTags) {
      return true;
    }
    return this.hasSynonyms;
  }

  @action
  async loadTagInfo() {
    if (this.canEditTags) {
      return;
    }

    const tag = this.args.tag;
    if (!tag) {
      return;
    }

    const tagId = String(tag.id || tag.name);

    if (this._lastTagId !== tagId) {
      this.tagInfo = null;
      this._lastTagId = tagId;
    }

    if (this.loading || this.tagInfo) {
      return;
    }

    this.loading = true;

    const findArgs = tag.id ? `${tag.slug}/${tag.id}` : tag.name;

    try {
      this.tagInfo = await this.store.find("tag-info", findArgs);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  handleClick() {
    if (this.canEditTags) {
      this.router.transitionTo(
        "tag.edit.tab",
        this.args.tag.slug,
        this.args.tag.id,
        "general"
      );
    }
  }

  <template>
    <div {{didInsert this.loadTagInfo}} {{didUpdate this.loadTagInfo @tag}}>
      {{#if this.canEditTags}}
        <DButton
          @icon="wrench"
          @ariaLabel={{i18n "tagging.edit"}}
          @title={{i18n "tagging.edit"}}
          @action={{this.handleClick}}
          id="show-tag-info"
          class="btn-default"
        />
      {{else if this.hasSynonyms}}
        <DTooltip @identifier="tag-synonyms-tooltip">
          <:trigger>
            <DButton
              @icon="circle-info"
              @ariaLabel={{i18n "tagging.info"}}
              @title={{i18n "tagging.info"}}
              id="show-tag-info"
              class="btn-default"
            />
          </:trigger>
          <:content>
            <div class="tag-synonyms-tooltip">
              {{i18n "tagging.synonyms_inline" base_tag_name=this.tagInfo.name}}
              {{discourseTags null tags=this.tagInfo.synonyms}}
            </div>
          </:content>
        </DTooltip>
      {{/if}}
    </div>
  </template>
}
