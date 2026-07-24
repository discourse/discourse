import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { concat } from "@ember/helper";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

interface DInlineFloatSignature {
  Args: {
    /** The float instance to render. */
    instance: FloatKitInstance;

    /** Whether to trap Tab focus within the content. */
    trapTab?: boolean;

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
        @closeModal={{@instance.close}}
        @hideHeader={{true}}
        data-identifier={{@instance.options.identifier}}
        data-content
        class={{dConcatClass
          "fk-d-menu-modal"
          (concat @instance.options.identifier "-content")
        }}
      >
        {{#if @instance.options.component}}
          <@instance.options.component
            @data={{@instance.options.data}}
            @close={{@instance.close}}
          />
        {{else}}
          {{@instance.options.content}}
        {{/if}}
      </DModal>
    {{else}}
      <DFloatBody
        @instance={{@instance}}
        @trapTab={{@trapTab}}
        @mainClass={{@mainClass}}
        @innerClass={{@innerClass}}
        @role={{@role}}
        @portalOutletElement={{@instance.portalOutletElement}}
        @inline={{@inline}}
      >
        {{#if @instance.options.component}}
          <@instance.options.component
            @data={{@instance.options.data}}
            @close={{@instance.close}}
          />
        {{else}}
          {{@instance.options.content}}
        {{/if}}
      </DFloatBody>
    {{/if}}
  {{/if}}
</template>;

export default DInlineFloat;
