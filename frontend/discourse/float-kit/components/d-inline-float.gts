import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import type Site from "discourse/models/site";
import { and } from "discourse/truth-helpers";
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

export default class DInlineFloat extends Component<DInlineFloatSignature> {
  @service declare site: Site;

  <template>
    {{#if @instance.expanded}}
      {{#if (and this.site.mobileView @instance.options.modalForMobile)}}
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
  </template>
}
