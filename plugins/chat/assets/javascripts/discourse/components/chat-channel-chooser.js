import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "discourse/select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "discourse/select-kit/components/select-kit";
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
