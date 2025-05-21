import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import DButton from "discourse/components/d-button";

export default class FKPrimaryActions extends Component {
  <template>
    {{yield
      (hash Button=(component DButton class="form-kit__button btn-flat"))
    }}
  </template>
}
