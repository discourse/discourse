import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import { makeArray } from "discourse/lib/helpers";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import { i18n } from "discourse-i18n";

export default class FKControlTagChooser extends FKBaseControl {
  static controlType = "tag-chooser";

  @service siteSettings;

  get maximum() {
    return (
      this.args.maximum ??
      this.args.field.args.maximum ??
      (this.args.unlimited ? false : undefined)
    );
  }

  get multiple() {
    return this.maximum !== 1;
  }

  get suggestRecent() {
    return (
      this.args.prioritizeRecentTags ??
      this.args.field.args.prioritizeRecentTags
    );
  }

  get value() {
    return this.multiple
      ? this.args.field.value
      : (this.args.field.value?.[0] ?? null);
  }

  @action
  handleChange(tags) {
    this.args.field.set(tags);
  }

  @action
  handleSelectChange(value) {
    if (this.multiple) {
      this.args.field.set(value);
      return;
    }
    this.args.field.set(makeArray(value));
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Keep the control switch until rollout completes. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelectTag
        class="form-kit__control-tag-chooser"
        @allowCreate={{@allowCreate}}
        @categoryId={{@categoryId}}
        @describedBy={{@field.describedBy}}
        @disabled={{@field.disabled}}
        @exclude={{@blockedTags}}
        @excludeSynonyms={{@excludeSynonyms}}
        @excludeTagsWithSynonyms={{@excludeTagsWithSynonyms}}
        @id={{@field.id}}
        @ignoreRestrictions={{@showAllTags}}
        @invalid={{if @field.error true false}}
        @label={{@field.title}}
        @maximum={{this.maximum}}
        @multiple={{this.multiple}}
        @onChange={{this.handleSelectChange}}
        @placeholder={{if @placeholder (i18n @placeholder)}}
        @suggestRecent={{this.suggestRecent}}
        @value={{this.value}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy control after rollout. }}
      <TagChooser
        class="form-kit__control-tag-chooser"
        @allowCreate={{@allowCreate}}
        @blockedTags={{@blockedTags}}
        @categoryId={{@categoryId}}
        @everyTag={{@showAllTags}}
        @excludeHasSynonyms={{@excludeTagsWithSynonyms}}
        @excludeSynonyms={{@excludeSynonyms}}
        @onChange={{this.handleChange}}
        @options={{hash
          disabled=@field.disabled
          filterPlaceholder=@placeholder
          maximum=@maximum
          mobilePlacement=@mobilePlacement
          prioritizeRecentTags=@prioritizeRecentTags
        }}
        @tags={{@field.value}}
        @unlimitedTagCount={{@unlimited}}
      />
    {{/if}}
  </template>
}
