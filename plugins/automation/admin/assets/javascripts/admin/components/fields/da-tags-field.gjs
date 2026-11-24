import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import BaseField from "./da-base-field.gjs";
import DAFieldDescription from "./da-field-description.gjs";
import DAFieldLabel from "./da-field-label.gjs";

export default class TagsField extends BaseField {
  @service siteSettings;

  @action
  onChangeTags(tags) {
    if (isBlank(tags)) {
      tags = undefined;
    } else {
      tags = tags.map((t) => (typeof t === "string" ? t : t.name));
    }

    this.mutValue(tags);
  }

  <template>
    <section class="field tags-field">
      <div class="control-group">
        <DAFieldLabel @field={{@field}} @label={{@label}} />

        <div class="controls">
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelectTag
              @allowCreate={{false}}
              @disabled={{@field.isDisabled}}
              @emit="names"
              @ignoreRestrictions={{true}}
              @maximum={{false}}
              @multiple={{true}}
              @onChange={{this.onChangeTags}}
              @texts={{hash ariaLabel=@label}}
              @value={{readonly @field.metadata.value}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <TagChooser
              @everyTag={{true}}
              @onChange={{this.onChangeTags}}
              @options={{hash allowAny=false disabled=@field.isDisabled}}
              @tags={{readonly @field.metadata.value}}
              @unlimitedTagCount={{true}}
            />
          {{/if}}

          <DAFieldDescription @description={{@description}} />
        </div>
      </div>
    </section>
  </template>
}
