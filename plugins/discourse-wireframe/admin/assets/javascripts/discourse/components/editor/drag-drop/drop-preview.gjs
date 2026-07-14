// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";

/**
 * The editor's single drop indicator. Reads the active slot-insert overlay
 * from `wireframeDragOverlay.slotPreview` and paints exactly one
 * absolutely-positioned rectangle at the descriptor's geometry,
 * with the operation label rendered as a small badge in the
 * top-left corner.
 *
 * Mounted once at the editor shell level so by construction there
 * can never be more than one drop indicator visible.
 *
 * The descriptor's `geometry` is in viewport coordinates (`top`,
 * `left`, `width`, `height` in CSS pixels). The overlay uses
 * `position: fixed` anchored at `top: 0; left: 0` and `translate3d`
 * to reach the target rectangle — translate is composited (no layout
 * or paint), where `top`/`left` writes force layout on every
 * dragover. Width / height still need to update with the descriptor
 * but those change far less frequently than position during a drag.
 *
 * `null` descriptor = no overlay rendered (`{{#if}}` guard at the
 * top of the template), so when scopes clear their preview the
 * indicator disappears immediately.
 */
export default class DropPreview extends Component {
  @service wireframeDragOverlay;

  get preview() {
    return this.wireframeDragOverlay.slotPreview;
  }

  get style() {
    const g = this.preview?.geometry;
    if (!g) {
      return null;
    }
    return trustHTML(
      `transform: translate3d(${g.left}px, ${g.top}px, 0); ` +
        `width: ${g.width}px; height: ${g.height}px;`
    );
  }

  <template>
    {{#if this.preview}}
      <div
        class="wireframe-drop-preview wireframe-drop-preview--{{this.preview.previewKind}}
          wireframe-drop-preview--{{this.preview.validity}}"
        style={{this.style}}
        aria-hidden="true"
      >
        {{#if this.preview.label}}
          <span class="wireframe-drop-preview__label">
            {{this.preview.label}}
          </span>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
