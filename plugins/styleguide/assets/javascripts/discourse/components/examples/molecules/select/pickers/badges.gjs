import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dIconOrImage from "discourse/ui-kit/helpers/d-icon-or-image";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { BADGES } from "../../../../../lib/select-fixtures";

export default class BadgesSelectExample extends Component {
  @tracked value = 3;

  items = BADGES.map((badge) => ({
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
