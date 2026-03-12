import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import concatClass from "discourse/ui-kit/helpers/d-concat-class";
import replaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

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
      @translatedLabel={{replaceEmoji @definition.text.text}}
      @action={{this.createInteraction}}
      id={{@definition.action_id}}
      class={{concatClass
        "block__button"
        (if @definition.style (concat "btn-" @definition.style))
      }}
    />
  </template>
}
