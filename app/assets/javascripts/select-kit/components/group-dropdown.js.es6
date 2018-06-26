import ComboBoxComponent from "select-kit/components/combo-box";
import DiscourseURL from "discourse/lib/url";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["group-dropdown"],
  classNames: "group-dropdown",
  content: Ember.computed.alias("groups"),
  tagName: "li",
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
  allowAutoSelectFirst: false,
  valueAttribute: "name",

  @computed("content")
  filterable(content) {
    return content && content.length >= 10;
  },

  computeHeaderContent() {
    let content = this._super();

    if (!this.get("hasSelection")) {
      content.label = `<span>${I18n.t("groups.index.all")}</span>`;
    }

    return content;
  },

  @computed
  collectionHeader() {
    if (
      this.siteSettings.enable_group_directory ||
      (this.currentUser && this.currentUser.get("staff"))
    ) {
      return `
        <a href="${Discourse.getURL("/groups")}" class="group-dropdown-filter">
          ${I18n.t("groups.index.all").toLowerCase()}
        </a>
      `.htmlSafe();
    }
  },

  actions: {
    onSelect(groupName) {
      DiscourseURL.routeTo(Discourse.getURL(`/groups/${groupName}`));
    }
  }
});
