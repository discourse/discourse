import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export default class Button extends Component {
  @tracked interacting = false;

  @action
  async createInteraction() {
    this.interacting = true;
    try {
      await this.args.createInteraction(this.args.definition.action_id);
    } finally {
      this.interacting = false;
    }
  }

  <template>
    <DButton
      @isLoading={{this.interacting}}
      @translatedLabel={{dReplaceEmoji @definition.text.text}}
      @action={{this.createInteraction}}
      id={{@definition.action_id}}
      class={{dConcatClass
        "block__button"
        (if @definition.style (concat "btn-" @definition.style))
      }}
    />
  </template>
}
