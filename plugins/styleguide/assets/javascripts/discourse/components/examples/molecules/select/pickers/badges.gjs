import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";

export default class BadgesSelectExample extends Component {
  @tracked value = 3;

  items = [
    {
      id: 1,
      name: "Welcome",
      icon: "heart",
      rarity: "bronze",
      grantCount: 41208,
    },
    {
      id: 2,
      name: "Nice post",
      icon: "star",
      rarity: "bronze",
      grantCount: 8834,
    },
    {
      id: 3,
      name: "Good post",
      icon: "star",
      rarity: "silver",
      grantCount: 1206,
    },
    {
      id: 4,
      name: "Great post",
      icon: "star",
      rarity: "gold",
      grantCount: 94,
    },
    {
      id: 5,
      name: "Editor",
      icon: "pencil",
      rarity: "bronze",
      grantCount: 6521,
    },
    {
      id: 6,
      name: "Autobiographer",
      icon: "user",
      rarity: "bronze",
      grantCount: 3390,
    },
    {
      id: 7,
      name: "Anniversary",
      icon: "cake-candles",
      rarity: "silver",
      grantCount: 712,
    },
    {
      id: 8,
      name: "Leader",
      icon: "certificate",
      rarity: "gold",
      grantCount: 23,
    },
  ].map((badge) => ({
    ...badge,
    grantLabel: i18n("styleguide.sections.select.pickers.badges.granted", {
      count: badge.grantCount,
    }),
  }));

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-badges"
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.update}}
      @variant="button"
    >
      <:selection as |badge|>
        <span class="select-examples__row select-examples__row--glyph">
          <span class="select-showcases__badge-icon --{{badge.rarity}}">
            {{dIconOrImage badge}}
          </span>
          {{badge.name}}
        </span>
      </:selection>

      <:item as |badge|>
        <span class="select-examples__row select-examples__row--glyph">
          <span class="select-showcases__badge-icon --{{badge.rarity}}">
            {{dIconOrImage badge}}
          </span>
          <span class="select-examples__primary">{{badge.name}}</span>
          <span class="select-examples__meta">{{badge.grantLabel}}</span>
        </span>
      </:item>
    </DSelect>
  </template>
}
