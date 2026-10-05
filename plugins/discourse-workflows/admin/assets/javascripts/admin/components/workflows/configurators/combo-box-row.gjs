import SelectKitRow from "discourse/select-kit/components/select-kit/select-kit-row";

export default class ComboBoxRow extends SelectKitRow {
  <template>
    <span class="workflows-combo-box-option">
      <span class="workflows-combo-box-option__name">{{this.label}}</span>
      <span class="workflows-combo-box-option__badge">{{this.item.badge}}</span>
    </span>
  </template>
}
