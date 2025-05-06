import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import DEditor from "discourse/components/d-editor";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default class PostTranslationEditor extends Component {
  @service composer;
  @service siteSettings;

  get availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  }

  <template>
    <div>
      <DropdownSelectBox
        @nameProperty="name"
        @valueProperty="value"
        @value={{this.composer.selectedTranslationLocale}}
        @content={{this.availableLocales}}
        @options={{hash
          icon="globe"
          showCaret=true
          filterable=true
          disabled=this.composer.loading
          placement="bottom-start"
          translatedNone=(i18n "composer.translations.select")
        }}
        class="translation-selector-dropdown btn-small"
      />
    </div>

    {{#if this.composer.model.post.firstPost}}
      <div class="topic-title-translator title-and-category with-preview">
        <TextField
          @value={{this.composer.title}}
          @id="translated-topic-title"
          @maxLength={{this.siteSettings.max_topic_title_length}}
          @placeholder={{this.composer.model.topic.title}}
          @disabled={{this.composer.loading}}
          @autocomplete="off"
        />
      </div>
    {{/if}}

    <div class="d-editor translation-editor">
      <DEditor
        @value={{this.composer.model.reply}}
        @placeholder="composer.translations.placeholder"
        @forcePreview={{true}}
        @processPreview={{false}}
        @loading={{this.composer.loading}}
        @hijackPreview={{this.composer.hijackPreview}}
        @disabled={{this.composer.disableTextarea}}
        @onSetup={{@setupEditor}}
        @disableSubmit={{this.composer.disableSubmit}}
        @topicId={{this.composer.model.topic.id}}
        @categoryId={{this.composer.model.category.id}}
        @outletArgs={{hash composer=this.composer.model editorType="composer"}}
      />
    </div>
  </template>
}
