import Component from "@glimmer/component";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import SpinnerSmallExample from "../../examples/spinner-small";
import spinnerSmallSource from "../../examples/spinner-small.gjs?source=template";

export default class Spinners extends Component {
  get spinnerRegularCode() {
    return `<div class="spinner"></div>`;
  }

  <template>
    <StyleguideExample @title="spinner - small" @code={{spinnerSmallSource}}>
      <SpinnerSmallExample />
    </StyleguideExample>

    <StyleguideExample
      @title="spinner - regular"
      @code={{this.spinnerRegularCode}}
    >
      <div class="spinner"></div>
    </StyleguideExample>
  </template>
}
