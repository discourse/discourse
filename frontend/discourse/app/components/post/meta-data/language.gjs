import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class PostMetaDataLanguage extends Component {
  @service languageNameLookup;
  @service site;
  @service tooltip;

  get language() {
    const lang = this.args.post?.language;
    return this.languageNameLookup.getLanguageName(lang);
  }

  get outdated() {
    return this.args.post?.localization_outdated;
  }

  get tooltipText() {
    const i18nKey = this.outdated
      ? "post.original_language_and_outdated"
      : "post.original_language";

    return `${i18n(i18nKey, {
      language: this.language,
    })}. ${this.translatePrompt}`;
  }

  get translatePrompt() {
    return this.site.mobileView
      ? i18n("post.tap_to_show_original")
      : i18n("post.click_to_show_original");
  }

  @action
  translateOnDesktop(event) {
    if (this.site.mobileView) {
      return;
    }

    return this.translate(event);
  }

  @action
  async translate(event) {
    event?.preventDefault();

    await this.tooltip.close("post-language");

    try {
      await this.args.post?.toggleLocalizedContent();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="post-info post-language">
      <PluginOutlet
        @name="post-language-indicator"
        @outletArgs={{lazyHash
          post=@post
          language=this.language
          outdated=this.outdated
          tooltipText=this.tooltipText
          translate=this.translate
        }}
      >
        <DTooltip
          class={{if this.outdated "heatmap-low"}}
          @identifier="post-language"
          @icon="language"
          {{on "click" this.translateOnDesktop}}
        >
          <:content>
            <button
              type="button"
              class="post-language__original-language"
              {{on "click" this.translate}}
            >{{this.tooltipText}}</button>
            <div class="post-language__disclaimer">{{i18n
                "post.ai_translation_disclaimer"
              }}</div>
          </:content>
        </DTooltip>
      </PluginOutlet>
    </div>
  </template>
}
