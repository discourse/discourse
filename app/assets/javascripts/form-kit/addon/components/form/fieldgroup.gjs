import Component from "@glimmer/component";

export default class FormFieldgroup extends Component {
  <template>
    <div class="d-form-fieldgroup">
      {{yield}}
    </div>
  </template>
}
