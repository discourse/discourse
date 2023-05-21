import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";
import { next } from "@ember/runloop";
import PermissionType from "discourse/models/permission-type";
import I18n from "I18n";
import { bind } from "discourse-common/utils/decorators";

export default class NewTopicSectionButton {
  constructor({
    topicTrackingState,
    currentUser,
    appEvents,
    router,
    siteSettings,
    inMoreDrawer,
    overridenName,
    overridenIcon,
  } = {}) {
    this.router = router;
    this.topicTrackingState = topicTrackingState;
    this.currentUser = currentUser;
    this.appEvents = appEvents;
    this.siteSettings = siteSettings;
    this.inMoreDrawer = inMoreDrawer;
    this.overridenName = overridenName;
    this.overridenIcon = overridenIcon;
  }

  get name() {
    return "new-topic";
  }

  get prefixValue() {
    return this.overridenIcon || "plus";
  }

  get text() {
    return I18n.t(
      `sidebar.sections.community.links.${this.overridenName.toLowerCase()}.content`,
      { defaultValue: this.overridenName }
    );
  }

  get shouldDisplay() {
    return this.currentUser;
  }

  @bind
  action() {
    const composerArgs = {
      action: Composer.CREATE_TOPIC,
      draftKey: Composer.NEW_TOPIC_KEY,
    };

    const controller = getOwner(this).lookup("controller:navigation/category");
    const category = controller.category;

    if (category && category.permission === PermissionType.FULL) {
      composerArgs.categoryId = category.id;
    }

    next(() => {
      getOwner(this).lookup("controller:composer").open(composerArgs);
    });
  }
}
