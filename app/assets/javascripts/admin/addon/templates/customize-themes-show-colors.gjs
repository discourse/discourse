import RouteTemplate from "ember-route-template";
import { gt } from "truth-helpers";
import ChangesBanner from "admin/components/changes-banner";
import ColorPaletteEditor from "admin/components/color-palette-editor";

export default RouteTemplate(
  <template>
    <ColorPaletteEditor
      @colors={{@controller.model.colorPalette.colors}}
      @onLightColorChange={{@controller.onLightColorChange}}
      @onDarkColorChange={{@controller.onDarkColorChange}}
      @hideRevertButton={{true}}
    />
    {{#if (gt @controller.pendingChangesCount 0)}}
      <ChangesBanner
        @bannerLabel={{@controller.pendingChangesBannerLabel}}
        @saveLabel={{@controller.pendingChangesSaveLabel}}
        @discardLabel={{@controller.pendingChangesDiscardLabel}}
        @save={{@controller.save}}
        @discard={{@controller.discard}}
      />
    {{/if}}
  </template>
);
