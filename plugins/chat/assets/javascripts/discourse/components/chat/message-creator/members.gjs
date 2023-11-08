import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import icon from "discourse-common/helpers/d-icon";
import eq from "truth-helpers/helpers/eq";
import Member from "./member";

export default class members extends Component {
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
        this.#getPrevious(this.args.members, this.args.highlightedMember)
      );

      return;
    }
    if (event.key === "ArrowRight" && event.target.value === "") {
      event.preventDefault();
      event.stopPropagation();

      this.args.onHighlightMember(
        this.#getNext(this.args.members, this.args.highlightedMember)
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

  #getNext(list, current = null) {
    if (list.length === 0) {
      return null;
    }

    list = list.filterBy("enabled");

    if (current?.identifier) {
      const currentIndex = list
        .mapBy("identifier")
        .indexOf(current?.identifier);

      if (currentIndex < list.length - 1) {
        return list.objectAt(currentIndex + 1);
      } else {
        return list[0];
      }
    } else {
      return list[0];
    }
  }

  #getPrevious(list, current = null) {
    if (list.length === 0) {
      return null;
    }

    list = list.filterBy("enabled");

    if (current?.identifier) {
      const currentIndex = list
        .mapBy("identifier")
        .indexOf(current?.identifier);

      if (currentIndex > 0) {
        return list.objectAt(currentIndex - 1);
      } else {
        return list.objectAt(list.length - 1);
      }
    } else {
      return list.objectAt(list.length - 1);
    }
  }

  <template>
    <div class="chat-message-creator__members-container">
      <div class="chat-message-creator__members">
        {{icon "search"}}

        {{#each @members as |member|}}
          <Member
            @member={{member}}
            @onSelect={{@onSelectMember}}
            @highlighted={{eq member @highlightedMember}}
          />
        {{/each}}

        <Input
          placeholder="...add more users"
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
