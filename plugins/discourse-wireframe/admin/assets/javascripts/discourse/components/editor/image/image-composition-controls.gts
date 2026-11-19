import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import type { ComponentLike } from "@glint/template";
import {
  type BlockImageValue,
  imageComposition,
} from "discourse/blocks/image-value";
import FKControlInputUntyped from "discourse/form-kit/components/fk/control/input";
import noop from "discourse/helpers/noop";
import { i18n } from "discourse-i18n";
import ImagePositionPicker, {
  type PercentagePosition,
} from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-position-picker";
import InspectorSegmentedField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-segmented-field";
import WireframeImageCompositionService, {
  ImageEditTarget,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-composition";

/** TODO(devxp-typescript-pending): remove when the input exports a signature. */
const FKControlInput = FKControlInputUntyped as unknown as ComponentLike<{
  Args: {
    type: "number";
    after: string;
    field: {
      hasExplicitType: boolean;
      id?: string;
      value: string | number;
      set: () => void;
    };
  };
  Element: HTMLInputElement;
}>;

interface ImageCompositionControlsSignature {
  Args: {
    /** Stable image argument being edited. */
    target: ImageEditTarget;
    /** Persisted image value, excluding temporary previews. */
    value: BlockImageValue;
    /** Shows only fit in the quick-action popup. */
    compact?: boolean;
  };
}

export default class ImageCompositionControls extends Component<ImageCompositionControlsSignature> {
  @service declare wireframeImageComposition: WireframeImageCompositionService;

  @tracked _zoomDraft: string | null = null;

  willDestroy(): void {
    if (this.wireframeImageComposition.matches(this.args.target)) {
      this.wireframeImageComposition.cancel();
    }
    super.willDestroy();
  }

  /** Each setting is its own labelled field; the ids tie label to control. */
  get fitLabelId(): string {
    return `${guidFor(this)}-fit`;
  }

  get positionLabelId(): string {
    return `${guidFor(this)}-position`;
  }

  get zoomInputId(): string {
    return `${guidFor(this)}-zoom`;
  }

  get composition() {
    return this.wireframeImageComposition.matches(this.args.target)
      ? (this.wireframeImageComposition.draft ??
          imageComposition(this.args.value))
      : imageComposition(this.args.value);
  }

  get fitOptions() {
    return [
      { value: "cover", label: i18n("wireframe.inspector.image.fill") },
      { value: "contain", label: i18n("wireframe.inspector.image.fit") },
    ];
  }

  get zoomValue(): string | number {
    return this._zoomDraft ?? this.composition.zoom;
  }

  @action
  cancel(): void {
    this._zoomDraft = null;
    this.wireframeImageComposition.cancel();
  }

  @action
  changeFit(fit: string): void {
    if (fit === "cover" || fit === "contain") {
      this.wireframeImageComposition.change(this.args.target, { fit });
    }
  }

  @action
  changePosition(position: PercentagePosition): void {
    this.wireframeImageComposition.change(this.args.target, { position });
  }

  @action
  keyDown(event: KeyboardEvent): void {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.cancel();
    } else if (event.key === "Enter") {
      event.preventDefault();
      this.zoom(true, event);
    }
  }

  @action
  previewPosition(position: PercentagePosition): void {
    this.wireframeImageComposition.preview(this.args.target, { position });
  }

  @action
  zoom(commit: boolean, event: Event): void {
    const input = event.currentTarget;
    if (!(input instanceof HTMLInputElement)) {
      return;
    }
    this._zoomDraft = !commit && input.type === "number" ? input.value : null;
    if (!Number.isFinite(input.valueAsNumber)) {
      if (commit) {
        input.value = String(this.composition.zoom);
      }
      return;
    }
    const patch = { zoom: input.valueAsNumber };
    if (commit) {
      this.wireframeImageComposition.change(this.args.target, patch);
    } else {
      this.wireframeImageComposition.preview(this.args.target, patch);
    }
  }

  <template>
    {{#if @compact}}
      <fieldset class="wireframe-image-composition --compact">
        <legend class="sr-only">{{i18n
            "wireframe.inspector.image.composition"
          }}</legend>
        <div class="wireframe-image-composition__fit">
          <span>{{i18n "wireframe.inspector.image.fit"}}</span>
          <InspectorSegmentedField
            @items={{this.fitOptions}}
            @onChange={{this.changeFit}}
            @value={{this.composition.fit}}
          />
        </div>
      </fieldset>
    {{else}}
      {{! Three independent FormKit-style fields, each with its own label and
        container, so the host form treats them as siblings of the image field
        rather than as part of its content. }}
      <div
        aria-labelledby={{this.fitLabelId}}
        class="form-kit__container form-kit__field wireframe-image-composition__fit"
        role="group"
      >
        <span class="form-kit__container-title" id={{this.fitLabelId}}>{{i18n
            "wireframe.inspector.image.fit"
          }}</span>
        <div class="form-kit__container-content">
          <InspectorSegmentedField
            @dropdown={{true}}
            @items={{this.fitOptions}}
            @onChange={{this.changeFit}}
            @value={{this.composition.fit}}
          />
        </div>
      </div>
      <div
        aria-labelledby={{this.positionLabelId}}
        class="form-kit__container form-kit__field wireframe-image-composition__position"
        role="group"
      >
        <span
          class="form-kit__container-title"
          id={{this.positionLabelId}}
        >{{i18n "wireframe.position_picker.label"}}</span>
        <div class="form-kit__container-content">
          <ImagePositionPicker
            @onCancel={{this.cancel}}
            @onChange={{this.changePosition}}
            @onPreview={{this.previewPosition}}
            @value={{this.composition.position}}
          />
        </div>
      </div>
      <div
        class="form-kit__container form-kit__field wireframe-image-composition__zoom"
      >
        <label class="form-kit__container-title" for={{this.zoomInputId}}>{{i18n
            "wireframe.inspector.image.zoom_short"
          }}</label>
        <div class="form-kit__container-content">
          {{! Native events retain raw drafts and the preview/commit boundaries. }}
          <FKControlInput
            max="250"
            min="100"
            step="1"
            @after="%"
            @field={{hash
              hasExplicitType=true
              id=this.zoomInputId
              value=this.zoomValue
              set=(noop)
            }}
            @type="number"
            {{on "input" (fn this.zoom false)}}
            {{on "blur" (fn this.zoom true)}}
            {{on "keydown" this.keyDown}}
          />
        </div>
      </div>
    {{/if}}
  </template>
}
