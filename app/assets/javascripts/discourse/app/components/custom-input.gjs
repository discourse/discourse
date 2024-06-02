import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import DButton from "discourse/components/d-button";

export default class CustomInput extends Component {
  <template>
    CUSTOM INPUT

    <DButton id={{@id}} @action={{fn @onChange "test"}} @icon="gear" />
  </template>
}
