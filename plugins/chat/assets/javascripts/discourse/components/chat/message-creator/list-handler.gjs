import Component from "@glimmer/component";
import { modifier } from "ember-modifier";

export default class ListHandler extends Component {
  handleKeydown = modifier((element) => {
    const handler = (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        event.stopPropagation();

        this.args.onHighlight(
          this.#getNext(this.args.items, this.args.highlightedItem?.identifier)
        );
      } else if (event.key === "ArrowUp") {
        event.preventDefault();
        event.stopPropagation();

        this.args.onHighlight(
          this.#getPrevious(
            this.args.items,
            this.args.highlightedItem?.identifier
          )
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

  #getNext(list, currentIdentifier = null) {
    if (list.length === 0) {
      return null;
    }

    list = list.filterBy("enabled");

    if (currentIdentifier) {
      const currentIndex = list.mapBy("identifier").indexOf(currentIdentifier);

      if (currentIndex < list.length - 1) {
        return list.objectAt(currentIndex + 1);
      } else {
        return list[0];
      }
    } else {
      return list[0];
    }
  }

  #getPrevious(list, currentIdentifier = null) {
    if (list.length === 0) {
      return null;
    }

    list = list.filterBy("enabled");

    if (currentIdentifier) {
      const currentIndex = list.mapBy("identifier").indexOf(currentIdentifier);

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
    <span style="display: contents" {{this.handleKeydown}} ...attributes>
      {{yield}}
    </span>
  </template>
}
