import Component from "@glimmer/component";

export default class FkFormText extends Component {
  <template>
    <p class="d-form-text" ...attributes>
      {{yield}}
    </p>
  </template>
}
