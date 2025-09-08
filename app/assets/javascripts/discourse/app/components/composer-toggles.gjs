import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class ComposerToggles extends Component {
  @service site;

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

  <template>
    <div class={{concatClass "composer-controls" this.additionalClasses}}>
      <span>
        <PluginOutlet @name="before-composer-toggles" @connectorTagName="div" />
      </span>

      {{#if this.site.mobileView}}
        <DButton
          @icon="bars"
          @action={{@toggleToolbar}}
          @title={{this.toggleToolbarTitle}}
          @preventFocus={{true}}
          class="btn-transparent toggle-toolbar btn-mini-toggle"
        />
      {{/if}}

      {{#if this.showFullScreenButton}}
        <DButton
          @icon={{this.fullscreenIcon}}
          @action={{@toggleFullscreen}}
          @title={{this.fullscreenTitle}}
          class="btn-transparent toggle-fullscreen btn-mini-toggle"
        />
      {{/if}}

      {{#if this.showCollapseButton}}
        <DButton
          @icon="angles-down"
          @action={{@toggleComposer}}
          @title="composer.collapse"
          class="btn-transparent toggler toggle-minimize btn-mini-toggle"
        />
      {{/if}}

      {{#if @saveAndClose}}
        <DButton
          @icon="xmark"
          @action={{@saveAndClose}}
          @title="composer.save_and_close"
          class="btn-transparent toggler toggle-save-and-close btn-mini-toggle"
        />
      {{/if}}
    </div>
  </template>
}
