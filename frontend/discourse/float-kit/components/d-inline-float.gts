import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import type { FloatCallback } from "discourse/float-kit/lib/constants";
import type FloatKitInstance from "discourse/float-kit/lib/float-kit-instance";
import type Site from "discourse/models/site";
import { and } from "discourse/truth-helpers";
import DModalUntyped from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// TODO(devxp-typescript-pending): drop this cast once DModal is authored in .gts with a
// real Signature, then import it directly. Untyped .gjs today gives it no arg/attr types.
const DModal = DModalUntyped as unknown as ComponentLike<{
  Element: HTMLElement;
  Args: { closeModal?: FloatCallback; hideHeader?: boolean };
  Blocks: { default: [] };
}>;

interface DInlineFloatSignature {
  Args: {
    instance: FloatKitInstance;
    trapTab?: boolean;
    mainClass?: string;
    innerClass?: string;
    role?: string;
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
