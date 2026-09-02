import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";

export default class ModalContainer extends Component {
  @service modal;

  @action
  closeModal(data) {
    this.modal.close(data);
  }

  <template>
    <div
      class="modal-container"
      {{didInsert this.modal.setContainerElement}}
    ></div>

    {{#if this.modal.activeModal}}
      {{#each (array this.modal.activeModal) as |activeModal|}}
        {{! #each ensures that the activeModal component/model are updated atomically }}
        <activeModal.component
          @closeModal={{this.closeModal}}
          @model={{activeModal.opts.model}}
        />
      {{/each}}
    {{/if}}
  </template>
}
