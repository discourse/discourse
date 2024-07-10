import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { inject as service } from "@ember/service";
import { and } from "truth-helpers";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import DFloatBody from "float-kit/components/d-float-body";

export default class DInlineFloat extends Component {
  @service site;

  <template>
    {{#if @instance.expanded}}
      {{#if (and this.site.mobileView @instance.options.modalForMobile)}}
        <DModal
          @closeModal={{@instance.close}}
          @hideHeader={{true}}
          data-identifier={{@instance.options.identifier}}
          data-content
          class={{concatClass
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
