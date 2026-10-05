import SelectedName from "discourse/select-kit/components/selected-name";

export default class ComboBoxSelectedName extends SelectedName {
  <template>
    <div
      class="select-kit-selected-name selected-name choice workflows-combo-box-option"
      data-name={{this.name}}
      data-value={{this.value}}
      lang={{this.lang}}
      title={{this.title}}
    >
      <span class="name workflows-combo-box-option__name">{{this.label}}</span>
      {{#if this.item.badge}}
        <span
          class="workflows-combo-box-option__badge"
        >{{this.item.badge}}</span>
      {{/if}}
    </div>
  </template>
}
