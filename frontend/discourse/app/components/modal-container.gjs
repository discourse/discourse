import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import deferForViewTransition from "discourse/helpers/defer-for-view-transition";

export default class ModalContainer extends Component {
  @service modal;

  @action
  closeModal(data) {
    this.modal.close(data);
  }

  <template>
    <div
      {{didInsert this.modal.setContainerElement}}
      class="modal-container"
    ></div>

    {{#let
      (deferForViewTransition this.modal.activeModal)
      as |deferredActiveModal|
    }}
      {{#if deferredActiveModal}}
        {{#each (array deferredActiveModal) as |activeModal|}}
          {{! #each ensures that the activeModal component/model are updated atomically }}
          <activeModal.component
            @model={{activeModal.opts.model}}
            @closeModal={{this.closeModal}}
          />
        {{/each}}
      {{/if}}
    {{/let}}
  </template>
}
