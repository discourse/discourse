import Component from "@glimmer/component";

export default class FormInvalidFeedback extends Component {
  <template>
    <div class="invalid-feedback">
      {{@message}}
    </div>
  </template>
}
