import Component from "@ember/component";
import { action, tracked, computed } from "@ember/object";

export default class SettingsEditor extends Component {
  @computed("theme")
  get editorContents() {
    return JSON.stringify(this.theme.settings, null, "\t");
  }

  set editorContents(value) {
    console.log(value)
    // console.log({editorContents:value})
    //  const settings = JSON.parse(value)
    // console.log({settings})
    this.theme.settings = value;
    return value;
    // return {theme:{settings}};
  }


}
