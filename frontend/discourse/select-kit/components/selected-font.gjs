import concatClass from "discourse/helpers/concat-class";
import SelectedNameComponent from "discourse/select-kit/components/selected-name";

export default class SelectedFont extends SelectedNameComponent {
  <template>
    <span class={{concatClass "name" this.item.classNames}}>
      {{this.label}}
    </span>
  </template>
}
