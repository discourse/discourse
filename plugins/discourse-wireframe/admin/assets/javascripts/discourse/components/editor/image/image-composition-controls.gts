import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import {
  type BlockImageValue,
  imageComposition,
} from "discourse/blocks/image-value";
import DButton from "discourse/ui-kit/d-button";
import DPositionPicker, {
  type PercentagePosition,
} from "discourse/ui-kit/d-position-picker";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import InspectorSegmentedField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-segmented-field";
import WireframeImageCompositionService, {
  ImageEditTarget,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-composition";

interface ImageCompositionControlsSignature {
  Args: {
    /** Stable image argument being edited. */
    target: ImageEditTarget;
    /** Persisted image value, excluding temporary previews. */
    value: BlockImageValue;
    /** Called after a canvas adjustment starts. */
    onReposition?: () => void;
    /** Shows only fit and canvas repositioning in the quick-action popup. */
    compact?: boolean;
  };
}

export default class ImageCompositionControls extends Component<ImageCompositionControlsSignature> {
  @service declare wireframeImageComposition: WireframeImageCompositionService;

  @tracked _zoomDraft: string | null = null;

  willDestroy(): void {
    if (
      this.wireframeImageComposition.matches(this.args.target) &&
      !this.wireframeImageComposition.repositioning
    ) {
      this.wireframeImageComposition.cancel();
    }
    super.willDestroy();
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
  reposition(): void {
    this.wireframeImageComposition.begin(this.args.target, true);
    this.args.onReposition?.();
  }

  @action
  reset(): void {
    this.wireframeImageComposition.change(this.args.target, imageComposition());
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
    <fieldset
      class={{dConcatClass
        "wireframe-image-composition"
        (if @compact "--compact")
      }}
    >
      <legend class={{if @compact "sr-only"}}>
        {{i18n "wireframe.inspector.image.composition"}}
      </legend>
      <div class="wireframe-image-composition__fit">
        {{#if @compact}}
          <span>{{i18n "wireframe.inspector.image.fit"}}</span>
        {{/if}}
        <InspectorSegmentedField
          @value={{this.composition.fit}}
          @items={{this.fitOptions}}
          @onChange={{this.changeFit}}
        />
      </div>
      {{#unless @compact}}
        <DPositionPicker
          @value={{this.composition.position}}
          @onPreview={{this.previewPosition}}
          @onChange={{this.changePosition}}
          @onCancel={{this.cancel}}
        />
        <div class="wireframe-image-composition__zoom">
          <span>{{i18n "wireframe.inspector.image.zoom"}}</span>
          <input
            type="range"
            aria-label={{i18n "wireframe.inspector.image.zoom"}}
            min="100"
            max="250"
            step="1"
            value={{this.composition.zoom}}
            {{on "input" (fn this.zoom false)}}
            {{on "change" (fn this.zoom true)}}
            {{on "keydown" this.keyDown}}
          />
          <input
            type="number"
            aria-label={{i18n "wireframe.inspector.image.zoom"}}
            min="100"
            max="250"
            step="1"
            value={{this.zoomValue}}
            {{on "input" (fn this.zoom false)}}
            {{on "blur" (fn this.zoom true)}}
            {{on "keydown" this.keyDown}}
          />
        </div>
      {{/unless}}
      <div class="wireframe-image-composition__actions">
        <DButton
          class={{if
            @compact
            "wireframe-image-editor-menu__action"
            "btn-default"
          }}
          @label={{if
            @compact
            "wireframe.inspector.image.reposition_short"
            "wireframe.inspector.image.reposition"
          }}
          @action={{this.reposition}}
        />
        {{#unless @compact}}
          <DButton
            class="btn-transparent"
            @label="wireframe.inspector.image.reset_composition"
            @action={{this.reset}}
          />
        {{/unless}}
      </div>
    </fieldset>
  </template>
}
