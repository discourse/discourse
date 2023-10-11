import Component from "@glimmer/component";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class DCardContainer extends Component {
  @service menu;
  @service card;

  @action
  closeCard(data) {
    this.card.close(data);
  }

  <template>
    {{!-- <div class="d-card-container" {{did-insert this.card.setContainerElement}}>
    </div> --}}

    {{#if this.card.activeCard}}
      {{#each (array this.card.activeCard) as |activeCard|}}
        {{! #each ensures that the activeCard component/model are updated atomically }}
        <activeCard.component
          @model={{activeCard.opts.model}}
          @closeCard={{this.closeCard}}
        />
      {{/each}}
    {{/if}}
  </template>
}
