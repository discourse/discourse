import UserChooserComponent from "select-kit/components/user-chooser";

export default UserChooserComponent.extend({
  pluginApiIdentifiers: ["email-group-user-chooser"],
  classNames: ["email-group-user-chooser"],
  classNameBindings: ["selectKit.options.fullWidthWrap:full-width-wrap"],
  valueProperty: "id",
  nameProperty: "name",

  modifyComponentForRow() {
    return "email-group-user-chooser-row";
  },

  selectKitOptions: {
    filterComponent: "email-group-user-chooser-filter",
    fullWidthWrap: false,
    autoWrap: false,
  },

  search() {
    const superPromise = this._super(...arguments);
    if (!superPromise) {
      return;
    }
    return superPromise.then((results) => {
      if (!results || results.length === 0) {
        return;
      }
      return results.map((item) => {
        const reconstructed = {};
        if (item.username) {
          reconstructed.id = item.username;
          if (item.username.includes("@")) {
            reconstructed.isEmail = true;
          } else {
            reconstructed.isUser = true;
            reconstructed.name = item.name;
            reconstructed.showUserStatus = this.showUserStatus;
          }
        } else if (item.name) {
          reconstructed.id = item.name;
          reconstructed.name = item.full_name;
          reconstructed.isGroup = true;
        }
        return Object.assign({}, item, reconstructed);
      });
    });
  },
});
