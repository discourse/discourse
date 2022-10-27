import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["chat-channel-chooser"],
  classNames: ["chat-channel-chooser"],

  selectKitOptions: {
    headerComponent: "chat-channel-chooser-header",
  },

  modifyComponentForRow() {
    return "chat-channel-chooser-row";
  },
});
