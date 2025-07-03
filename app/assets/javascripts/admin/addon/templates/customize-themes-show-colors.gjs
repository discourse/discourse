import Component from "@glimmer/component";
import { action } from "@ember/object";
import RouteTemplate from "ember-route-template";
import { gt } from "truth-helpers";
import { i18n } from "discourse-i18n";
import ChangesBanner from "admin/components/changes-banner";
import ColorPaletteEditor from "admin/components/color-palette-editor";

export default RouteTemplate(
  class extends Component {
    get pendingChangesBannerLabel() {
      return i18n("admin.customize.theme.unsaved_colors", {
        count: this.args.controller.colorPaletteChangeTracker.dirtyColorsCount,
      });
    }

    @action
    onLightColorChange(color, value) {
      color.hex = value;
      if (color.hex !== color.originalHex) {
        this.args.controller.colorPaletteChangeTracker.addDirtyLightColor(
          color.name
        );
      } else {
        this.args.controller.colorPaletteChangeTracker.removeDirtyLightColor(
          color.name
        );
      }
    }

    @action
    onDarkColorChange(color, value) {
      color.dark_hex = value;
      if (color.dark_hex !== color.originalDarkHex) {
        this.args.controller.colorPaletteChangeTracker.addDirtyDarkColor(
          color.name
        );
      } else {
        this.args.controller.colorPaletteChangeTracker.removeDirtyDarkColor(
          color.name
        );
      }
    }

    @action
    async save() {
      await this.args.model.changeColors();
      this.args.controller.colorPaletteChangeTracker.clear();
    }

    @action
    discard() {
      this.args.model.discardColorChanges();
      this.args.controller.colorPaletteChangeTracker.clear();
    }

    <template>
      <ColorPaletteEditor
        @colors={{@model.colorPalette.colors}}
        @onLightColorChange={{this.onLightColorChange}}
        @onDarkColorChange={{this.onDarkColorChange}}
        @hideRevertButton={{true}}
        @system={{@model.system}}
      />
      {{#if (gt @controller.colorPaletteChangeTracker.dirtyColorsCount 0)}}
        <ChangesBanner
          @bannerLabel={{this.pendingChangesBannerLabel}}
          @saveLabel={{i18n "admin.customize.theme.save_colors"}}
          @discardLabel={{i18n "admin.customize.theme.discard_colors"}}
          @save={{this.save}}
          @discard={{this.discard}}
        />
      {{/if}}
    </template>
  }
);
