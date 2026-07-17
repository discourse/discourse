import Component from "@glimmer/component";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import { applyValueTransformer } from "discourse/lib/transformer";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class ComposerToggles extends Component {
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

  get toggleToolbarTitle() {
    return this.args.showToolbar
      ? "composer.hide_toolbar"
      : "composer.show_toolbar";
  }

  get fullscreenTitle() {
    return this.args.composeState === "draft"
      ? "composer.open"
      : this.args.composeState === "fullscreen"
        ? "composer.exit_fullscreen"
        : "composer.enter_fullscreen";
  }

  get fullscreenIcon() {
    return this.args.composeState === "draft"
      ? "angles-up"
      : this.args.composeState === "fullscreen"
        ? "discourse-compress"
        : "discourse-expand";
  }

  get showFullScreenButton() {
    if (this.site.mobileView) {
      return false;
    }
    return !this.args.disableTextarea;
  }

  get showToolbarToggle() {
    // the redesigned composer keeps the toolbar fixed in the footer, so
    // there is nothing to toggle
    return this.site.mobileView && !this.siteSettings.enable_composer_redesign;
  }

  <template>
    <div class={{dConcatClass "composer-controls" this.additionalClasses}}>
      <PluginOutlet @name="before-composer-toggles" @connectorTagName="div" />

      {{#if this.showToolbarToggle}}
        <DButton
          @icon="bars"
          @action={{@toggleToolbar}}
          @title={{this.toggleToolbarTitle}}
          @preventFocus={{true}}
          class="btn-transparent toggle-toolbar btn-small"
        />
      {{/if}}

      {{#if this.showFullScreenButton}}
        <DButton
          @icon={{this.fullscreenIcon}}
          @action={{@toggleFullscreen}}
          @title={{this.fullscreenTitle}}
          class="btn-transparent toggle-fullscreen btn-small"
        />
      {{/if}}

      {{#if this.showCollapseButton}}
        <DButton
          @icon="angles-down"
          @action={{@toggleComposer}}
          @title="composer.collapse"
          class="btn-transparent toggler toggle-minimize btn-small"
        />
      {{/if}}

      {{#if @saveAndClose}}
        <DButton
          @icon="xmark"
          @action={{@saveAndClose}}
          @title="composer.save_and_close"
          class="btn-transparent toggler toggle-save-and-close btn-small"
        />
      {{/if}}
    </div>
  </template>
}
