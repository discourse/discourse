import Component from "@glimmer/component";
import { service } from "@ember/service";
import type { BlockImageValue } from "discourse/blocks/image-value";
import ImageCompositionControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-composition-controls";
import { isImageArgValue } from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";

interface InspectorImageCompositionSignature {
  Args: {
    /** Block that owns the image argument. */
    blockKey: string;
    /** The image argument's name. */
    argName: string;
  };
}

/**
 * Fit, position and zoom for an image argument, rendered as sibling fields of
 * the image field itself so each setting has its own container and label.
 * Shown once the image has a source.
 */
export default class InspectorImageComposition extends Component<InspectorImageCompositionSignature> {
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /** Live image value, read from the layout so edits show immediately. */
  get value(): BlockImageValue | null {
    void this.wireframeLayoutSignal.version;
    const entry = this.wireframeLayoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    const value = entry?.args?.[this.args.argName];
    return isImageArgValue(value) && value.url ? value : null;
  }

  get target() {
    return { blockKey: this.args.blockKey, argName: this.args.argName };
  }

  <template>
    {{#if this.value}}
      <ImageCompositionControls @target={{this.target}} @value={{this.value}} />
    {{/if}}
  </template>
}
