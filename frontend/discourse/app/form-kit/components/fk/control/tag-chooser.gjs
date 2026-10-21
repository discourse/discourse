import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import FKBaseControl from "discourse/form-kit/components/fk/control/base";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DTagChooser from "discourse/ui-kit/select/recipes/tags/d-tag-chooser";
import { i18n } from "discourse-i18n";

export default class FKControlTagChooser extends FKBaseControl {
  static controlType = "tag-chooser";

  @service siteSettings;

  @action
  handleChange(tags) {
    this.args.field.set(tags);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Keep the control switch until rollout completes. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DTagChooser
        class="form-kit__control-tag-chooser"
        @allowCreate={{@allowCreate}}
        @blockedTags={{@blockedTags}}
        @categoryId={{@categoryId}}
        @describedBy={{@field.describedBy}}
        @disabled={{@field.disabled}}
        @everyTag={{@showAllTags}}
        @excludeHasSynonyms={{@excludeTagsWithSynonyms}}
        @excludeSynonyms={{@excludeSynonyms}}
        @id={{@field.id}}
        @invalid={{if @field.error true false}}
        @label={{@field.title}}
        @maximum={{@maximum}}
        @onChange={{this.handleChange}}
        @placeholder={{if @placeholder (i18n @placeholder)}}
        @tags={{@field.value}}
        @unlimitedTagCount={{@unlimited}}
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
