import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { eq } from "truth-helpers";
import icon from "discourse-common/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { getNext, getPrevious } from "./lib/iterate-list";
import Member from "./member";

export default class Members extends Component {
  addMoreMembersLabel = i18n("chat.new_message_modal.user_search_placeholder");

  @action
  onFilter() {
    this.args.onFilter(...arguments);
  }

  @action
  registerFocusFilterAction(element) {
    this.args.registerFocusFilterAction(() => element.focus());
  }

  @action
  handleKeypress(event) {
    if (event.key === "Backspace" && event.target.value === "") {
      event.preventDefault();
      event.stopPropagation();

      if (!this.args.highlightedMember) {
        this.args.onHighlightMember(this.args.members.lastObject);
      } else {
        this.args.onSelectMember(this.args.highlightedMember);
      }

      return;
    }

    if (event.key === "ArrowLeft" && event.target.value === "") {
      event.preventDefault();
      event.stopPropagation();

      this.args.onHighlightMember(
        getPrevious(this.args.members, this.args.highlightedMember)
      );

      return;
    }
    if (event.key === "ArrowRight" && event.target.value === "") {
      event.preventDefault();
      event.stopPropagation();

      this.args.onHighlightMember(
        getNext(this.args.members, this.args.highlightedMember)
      );

      return;
    }

    if (event.key === "Enter" && this.args.highlightedMember) {
      event.preventDefault();
      event.stopPropagation();

      this.args.onSelectMember(this.args.highlightedMember);

      return;
    }

    this.highlightedMember = null;
  }

  <template>
    <div class="chat-message-creator__members-container">
      <div class="chat-message-creator__members">
        {{icon "magnifying-glass"}}

        {{#each @members as |member|}}
          <Member
            @member={{member}}
            @onSelect={{@onSelectMember}}
            @highlighted={{eq member @highlightedMember}}
          />
        {{/each}}

        <Input
          placeholder={{this.addMoreMembersLabel}}
          class="chat-message-creator__members-input"
          @value={{@filter}}
          autofocus={{true}}
          {{on "input" this.onFilter}}
          {{on "keydown" this.handleKeypress}}
          {{didInsert this.registerFocusFilterAction}}
        />
      </div>
    </div>
  </template>
}
