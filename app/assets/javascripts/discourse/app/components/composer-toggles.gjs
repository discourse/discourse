import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class ComposerToggles extends Component {
  @discourseComputed("composeState")
  toggleTitle(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "composer.abandon"
      : "composer.collapse";
  }

  @discourseComputed("showToolbar")
  toggleToolbarTitle(showToolbar) {
    return showToolbar ? "composer.hide_toolbar" : "composer.show_toolbar";
  }

  @discourseComputed("composeState")
  fullscreenTitle(composeState) {
    return composeState === "draft"
      ? "composer.open"
      : composeState === "fullscreen"
        ? "composer.exit_fullscreen"
        : "composer.enter_fullscreen";
  }

  @discourseComputed("composeState")
  toggleIcon(composeState) {
    return composeState === "draft" || composeState === "saving"
      ? "xmark"
      : "angles-down";
  }

  @discourseComputed("composeState")
  fullscreenIcon(composeState) {
    return composeState === "draft"
      ? "angles-up"
      : composeState === "fullscreen"
        ? "discourse-compress"
        : "discourse-expand";
  }

  @discourseComputed("disableTextarea")
  showFullScreenButton(disableTextarea) {
    if (this.site.mobileView) {
      return false;
    }
    return !disableTextarea;
  }

  <template>
    <div class="composer-controls">
      <span>
        <PluginOutlet @name="before-composer-toggles" @connectorTagName="div" />
      </span>

      {{#if this.site.mobileView}}
        <DButton
          @icon="bars"
          @action={{this.toggleToolbar}}
          @title={{this.toggleToolbarTitle}}
          @preventFocus={{true}}
          class="btn-transparent toggle-toolbar btn-mini-toggle"
        />
      {{/if}}

      {{#if this.showFullScreenButton}}
        <DButton
          @icon={{this.fullscreenIcon}}
          @action={{this.toggleFullscreen}}
          @title={{this.fullscreenTitle}}
          class="btn-transparent toggle-fullscreen btn-mini-toggle"
        />
      {{/if}}

      <DButton
        @icon={{this.toggleIcon}}
        @action={{this.toggleComposer}}
        @title={{this.toggleTitle}}
        class="btn-transparent toggler toggle-minimize btn-mini-toggle"
      />
    </div>
  </template>
}
