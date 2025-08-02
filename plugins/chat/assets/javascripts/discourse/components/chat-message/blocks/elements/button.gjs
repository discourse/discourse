import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import replaceEmoji from "discourse/helpers/replace-emoji";

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
      @id={{@definition.action_id}}
      @isLoading={{this.interacting}}
      @translatedLabel={{replaceEmoji @definition.text.text}}
      @action={{this.createInteraction}}
      class={{concatClass
        "block__button"
        (if @definition.style (concat "btn-" @definition.style))
      }}
    />
  </template>
}
