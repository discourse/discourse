import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import { i18n } from "discourse-i18n";

export default class ReviewableFieldTags extends Component {
  @service siteSettings;

  // The reviewable is not updated until the edit is saved, so the picked tags are held
  // here rather than read back from `@value`.
  @tracked editedValue;

  get value() {
    return this.editedValue ?? this.args.value;
  }

  @action
  onChange(tags) {
    this.editedValue = tags;

    this.args.valueChanged?.({
      target: {
        value: tags,
      },
    });
  }

  <template>
    {{#if this.siteSettings.enable_new_select_controls}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      <DSelectTag
        @allowCreate={{true}}
        @categoryId={{@tagCategoryId}}
        @legacyKind="mini-tag-chooser"
        @multiple={{true}}
        @onChange={{this.onChange}}
        @texts={{hash placeholder=(i18n "tagging.choose_for_topic")}}
        @value={{this.value}}
      />
    {{else}}
      {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
      <MiniTagChooser
        @onChange={{this.onChange}}
        @options={{hash categoryId=@tagCategoryId}}
        @value={{this.value}}
      />
    {{/if}}
  </template>
}
