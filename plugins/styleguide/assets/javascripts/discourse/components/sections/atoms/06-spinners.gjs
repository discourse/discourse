import Component from "@glimmer/component";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Spinners extends Component {
  get spinnerSmallCode() {
    return `<div class="spinner small"></div>`;
  }

  get spinnerRegularCode() {
    return `<div class="spinner"></div>`;
  }

  <template>
    <StyleguideExample @title="spinner - small" @code={{this.spinnerSmallCode}}>
      <div class="spinner small"></div>
    </StyleguideExample>

    <StyleguideExample
      @title="spinner - regular"
      @code={{this.spinnerRegularCode}}
    >
      <div class="spinner"></div>
    </StyleguideExample>
  </template>
}
