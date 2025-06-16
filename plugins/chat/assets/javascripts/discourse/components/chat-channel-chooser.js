import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import ChatChannelChooserHeader from "./chat-channel-chooser-header";
import ChatChannelChooserRow from "./chat-channel-chooser-row";

@classNames("chat-channel-chooser")
@selectKitOptions({
  headerComponent: ChatChannelChooserHeader,
})
@pluginApiIdentifiers("chat-channel-chooser")
export default class ChatChannelChooser extends ComboBoxComponent {
  modifyComponentForRow() {
    return ChatChannelChooserRow;
  }
}
