import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { concat } from "@ember/helper";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import FloatKitNotifyPositioned from "discourse/float-kit/modifiers/notify-positioned";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

interface DInlineFloatSignature {
  Args: {
    /** The float instance to render. */
    instance: FloatKitInstance;

    /** Whether to trap Tab focus within the content. */
    trapTab?: boolean;

    /**
     * Whether the content takes part in the tab sequence as if rendered inline after the trigger.
     * The non-containing alternative to `trapTab`; the two are mutually exclusive.
     */
    inlineTabOrder?: boolean;

    /** A class added to the outer float element. */
    mainClass?: string;

    /** A class added to the inner content element. */
    innerClass?: string;

    /** The ARIA role for the content. */
    role?: string;

    /** Whether to render in place instead of into the portal outlet. */
    inline?: boolean | null;
  };
}

/**
 * Renders an already-created float instance, choosing how to present it: a
 * full-screen modal on mobile when the instance opts into `modalForMobile`, and
 * otherwise the standard positioned body (see `DFloatBody`). It only renders
 * while the instance is expanded. This is the render path for floats created
 * through the service API, whose trigger lives elsewhere (see `DHeadlessMenu`
 * and `DHeadlessTooltip`); the declarative components render their own body
 * inline instead.
 */
const DInlineFloat: TemplateOnlyComponent<DInlineFloatSignature> = <template>
  {{#if @instance.expanded}}
    {{#if @instance.renderInModal}}
      <DModal
        class={{dConcatClass
          "fk-d-menu-modal"
          (concat @instance.options.identifier "-content")
        }}
        data-content
        data-identifier={{@instance.options.identifier}}
        @closeModal={{@instance.close}}
        @hideHeader={{true}}
        {{FloatKitNotifyPositioned @instance}}
      >
        {{#if @instance.options.component}}
          <@instance.options.component
            @close={{@instance.close}}
            @data={{@instance.options.data}}
          />
        {{else}}
          {{@instance.options.content}}
        {{/if}}
      </DModal>
    {{else}}
      <DFloatBody
        @inline={{@inline}}
        @inlineTabOrder={{@inlineTabOrder}}
        @innerClass={{@innerClass}}
        @instance={{@instance}}
        @mainClass={{@mainClass}}
        @portalOutletElement={{@instance.portalOutletElement}}
        @role={{@role}}
        @trapTab={{@trapTab}}
      >
        {{#if @instance.options.component}}
          <@instance.options.component
            @close={{@instance.close}}
            @data={{@instance.options.data}}
          />
        {{else}}
          {{@instance.options.content}}
        {{/if}}
      </DFloatBody>
    {{/if}}
  {{/if}}
</template>;

export default DInlineFloat;
