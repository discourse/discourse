import { action } from "@ember/object";
import { service } from "@ember/service";
import { RouteException } from "discourse/controllers/exception";
import User from "discourse/models/user";
import DiscourseRoute from "discourse/routes/discourse";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

export default class UserRoute extends DiscourseRoute {
  @service router;
  @service("search") searchService;
  @service appEvents;
  @service messageBus;

  beforeModel() {
    if (this.siteSettings.hide_user_profiles_from_public && !this.currentUser) {
      throw new RouteException({
        status: 403,
        desc: i18n("user.login_to_view_profile"),
      });
    }
  }

  model(params) {
    // If we're viewing the currently logged in user, return that object instead
    if (
      this.currentUser &&
      params.username.toLowerCase() === this.currentUser.username_lower
    ) {
      return this.currentUser;
    }

    return User.create({
      username: encodeURIComponent(params.username),
    });
  }

  afterModel() {
    const user = this.modelFor("user");

    return user
      .findDetails()
      .then(() => user.findStaffInfo())
      .then(() => user.statusManager.trackStatus())
      .catch(() => this.router.replaceWith("/404"));
  }

  serialize(model) {
    if (!model) {
      return {};
    }

    return { username: (model.username || "").toLowerCase() };
  }

  setupController(controller, user) {
    controller.set("model", user);
    this.searchService.searchContext = user.searchContext;
  }

  activate() {
    super.activate(...arguments);

    const user = this.modelFor("user");
    this.messageBus.subscribe(`/u/${user.username_lower}`, this.onUserMessage);
    this.messageBus.subscribe(
      `/u/${user.username_lower}/counters`,
      this.onUserCountersMessage
    );
  }

  deactivate() {
    super.deactivate(...arguments);

    const user = this.modelFor("user");
    this.messageBus.unsubscribe(
      `/u/${user.username_lower}`,
      this.onUserMessage
    );
    this.messageBus.unsubscribe(
      `/u/${user.username_lower}/counters`,
      this.onUserCountersMessage
    );
    user.statusManager.stopTrackingStatus();

    // Remove the search context
    this.searchService.searchContext = null;
  }

  @bind
  onUserMessage(data) {
    const user = this.modelFor("user");
    return user.loadUserAction(data);
  }

  @bind
  onUserCountersMessage(data) {
    const user = this.modelFor("user");
    user.setProperties(data);

    Object.entries(data).forEach(([key, value]) =>
      this.appEvents.trigger(
        `count-updated:${user.username_lower}:${key}`,
        value
      )
    );
  }

  titleToken() {
    const username = this.modelFor("user").username;
    return username ? username : null;
  }

  @action
  undoRevokeApiKey(key) {
    key.undoRevoke();
  }

  @action
  revokeApiKey(key) {
    key.revoke();
  }
}
