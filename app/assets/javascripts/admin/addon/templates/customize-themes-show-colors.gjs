import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import { gt } from "truth-helpers";
import { i18n } from "discourse-i18n";
import ChangesBanner from "admin/components/changes-banner";
import ColorPaletteEditor from "admin/components/color-palette-editor";

export default RouteTemplate(
  class extends Component {
    @service colorPaletteChangeTracker;

    get pendingChangesBannerLabel() {
      return i18n("admin.customize.theme.unsaved_colors", {
        count: this.colorPaletteChangeTracker.dirtyColorsCount,
      });
    }

    @action
    onLightColorChange(color, value) {
      color.hex = value;
      if (color.hex !== color.originalHex) {
        this.colorPaletteChangeTracker.addDirtyLightColor(color.name);
      } else {
        this.colorPaletteChangeTracker.removeDirtyLightColor(color.name);
      }
    }

    @action
    onDarkColorChange(color, value) {
      color.dark_hex = value;
      if (color.dark_hex !== color.originalDarkHex) {
        this.colorPaletteChangeTracker.addDirtyDarkColor(color.name);
      } else {
        this.colorPaletteChangeTracker.removeDirtyDarkColor(color.name);
      }
    }

    @action
    async save() {
      await this.args.model.changeColors();
      this.colorPaletteChangeTracker.clear();
    }

    @action
    discard() {
      this.args.model.discardColorChanges();
      this.colorPaletteChangeTracker.clear();
    }

    <template>
      <ColorPaletteEditor
        @colors={{@model.colorPalette.colors}}
        @onLightColorChange={{this.onLightColorChange}}
        @onDarkColorChange={{this.onDarkColorChange}}
        @hideRevertButton={{true}}
      />
      {{#if (gt this.colorPaletteChangeTracker.dirtyColorsCount 0)}}
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
