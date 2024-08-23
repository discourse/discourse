import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("chat-channel-chooser")
@selectKitOptions({
  headerComponent: "chat-channel-chooser-header",
})
@pluginApiIdentifiers("chat-channel-chooser")
export default class ChatChannelChooser extends ComboBoxComponent {
  modifyComponentForRow() {
    return "chat-channel-chooser-row";
  }
}
