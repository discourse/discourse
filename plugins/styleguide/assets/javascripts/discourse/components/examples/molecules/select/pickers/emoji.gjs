import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import DSelect from "discourse/ui-kit/select/d-select";

export default class EmojiSelectExample extends Component {
  @tracked value = "tada";

  groupLabel = (key) => key;

  items = [
    { id: "tada", name: "tada", group: "Celebration" },
    { id: "rocket", name: "rocket", group: "Celebration" },
    { id: "sparkles", name: "sparkles", group: "Celebration" },
    { id: "heart", name: "heart", group: "Celebration" },
    { id: "bug", name: "bug", group: "Development" },
    { id: "wrench", name: "wrench", group: "Development" },
    { id: "hammer", name: "hammer", group: "Development" },
    { id: "bulb", name: "bulb", group: "Development" },
    { id: "books", name: "books", group: "Writing" },
    { id: "memo", name: "memo", group: "Writing" },
    { id: "mag", name: "mag", group: "Writing" },
    { id: "lock", name: "lock", group: "Moderation" },
    { id: "warning", name: "warning", group: "Moderation" },
    { id: "eyes", name: "eyes", group: "Moderation" },
  ];

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-emoji"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.update}}
      @groupBy="group"
      @groupLabel={{this.groupLabel}}
      @variant="button"
    >
      <:selection as |item|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dEmoji item.name}}
          {{item.name}}
        </span>
      </:selection>

      <:item as |item|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dEmoji item.name}}
          <span class="select-examples__primary">{{item.name}}</span>
          <code class="select-showcases__shortcode" aria-hidden="true">
            :{{item.name}}:
          </code>
        </span>
      </:item>
    </DSelect>
  </template>
}
