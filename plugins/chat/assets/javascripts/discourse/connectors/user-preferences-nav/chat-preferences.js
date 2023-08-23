import Component from "@glimmer/component";

export default class ChatPreferences extends Component {
  static shouldRender({ model }, { siteSettings, currentUser }) {
    return siteSettings.chat_enabled && (model.can_chat || currentUser?.admin);
  }
}
