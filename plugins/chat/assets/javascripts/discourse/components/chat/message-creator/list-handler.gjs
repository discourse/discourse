import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import { getNext, getPrevious } from "./lib/iterate-list";

export default class ListHandler extends Component {
  handleKeydown = modifier((element) => {
    const handler = (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        event.stopPropagation();

        this.args.onHighlight(
          getNext(this.args.items, this.args.highlightedItem)
        );
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();

        this.args.onHighlight(
          getPrevious(this.args.items, this.args.highlightedItem)
        );
      } else if (event.key === "Enter" && this.args.highlightedItem) {
        event.preventDefault();
        event.stopPropagation();

        if (event.shiftKey && this.args.onShifSelect) {
          this.args.onShifSelect(this.args.highlightedItem);
        } else {
          this.args.onSelect(this.args.highlightedItem);
        }
      }
    };

    element.addEventListener("keydown", handler);

    return () => {
      element.removeEventListener("keydown", handler);
    };
  });

  <template>
    <span style="display: contents" {{this.handleKeydown}} ...attributes>
      {{yield}}
    </span>
  </template>
}
