import SelectedNameComponent from "discourse/select-kit/components/selected-name";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class SelectedFont extends SelectedNameComponent {
  <template>
    <span class={{dConcatClass "name" this.item.classNames}}>
      {{this.label}}
    </span>
  </template>
}
