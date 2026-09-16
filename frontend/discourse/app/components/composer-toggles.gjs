import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import { applyValueTransformer } from "discourse/lib/transformer";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class ComposerToggles extends Component {
  @service composer;
  @service site;
  @service siteSettings;

  get additionalClasses() {
    return applyValueTransformer("composer-toggles-class", "");
  }

  get showCollapseButton() {
    return (
      this.args.composeState !== "draft" && this.args.composeState !== "saving"
    );
  }

  get showPreviewToggle() {
    return this.args.composeState !== "draft";
  }

  get toggleToolbarTitle() {
    return this.args.showToolbar
      ? "composer.hide_toolbar"
      : "composer.show_toolbar";
  }

  get fullscreenTitle() {
    return this.args.composeState === "fullscreen"
      ? "composer.exit_fullscreen"
      : "composer.enter_fullscreen";
  }

  get fullscreenIcon() {
    return this.args.composeState === "fullscreen"
      ? "discourse-compress"
      : "discourse-expand";
  }

  get showFullScreenButton() {
    if (this.site.mobileView || this.args.composeState === "draft") {
      return false;
    }
    return !this.args.disableTextarea;
  }

  get showToolbarToggle() {
    return this.site.mobileView;
  }

  <template>
    <div class={{dConcatClass "composer-controls" this.additionalClasses}}>
      <PluginOutlet @connectorTagName="div" @name="before-composer-toggles" />

      {{#unless this.siteSettings.enable_composer_redesign}}
        {{#if this.showToolbarToggle}}
          <DButton
            class="btn-transparent toggle-toolbar btn-small"
            @action={{@toggleToolbar}}
            @icon="bars"
            @preventFocus={{true}}
            @title={{this.toggleToolbarTitle}}
          />
        {{/if}}
      {{/unless}}
      {{#if
        (and
          this.composer.allowPreview
          this.site.desktopView
          this.showPreviewToggle
        )
      }}
        <DButton
          class={{dConcatClass
            "btn-transparent btn-mini-toggle toggle-preview"
            (unless this.composer.isPreviewVisible "active")
          }}
          @action={{this.composer.togglePreview}}
          @icon="angles-left"
          @translatedTitle={{this.composer.toggleText}}
        />
      {{/if}}

      {{#if this.showFullScreenButton}}
        <DButton
          class="btn-transparent toggle-fullscreen btn-small"
          @action={{@toggleFullscreen}}
          @icon={{this.fullscreenIcon}}
          @title={{this.fullscreenTitle}}
        />
      {{/if}}

      {{#if this.showCollapseButton}}
        <DButton
          class="btn-transparent toggler toggle-minimize btn-small"
          @action={{@toggleComposer}}
          @icon="minus"
          @title="composer.collapse"
        />
      {{/if}}

      {{#if @saveAndClose}}
        <DButton
          class="btn-transparent toggler toggle-save-and-close btn-small"
          @action={{@saveAndClose}}
          @icon="xmark"
          @title="composer.save_and_close"
        />
      {{/if}}
    </div>
  </template>
}
