import Component from "@ember/component";

export default class SettingsEditor extends Component {
  didInsertElement() {}

  get settings() {
    return JSON.stringify(this.model, null, "\t");
  }
}
