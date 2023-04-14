import Flag from "discourse/lib/flag-targets/flag";

export default class PostFlag extends Flag {
  title() {
    return "flagging.title";
  }

  customSubmitLabel() {
    return "flagging.notify_action";
  }

  submitLabel() {
    return "flagging.action";
  }

  flagCreatedEvent() {
    return "post:flag-created";
  }

  flagsAvailable(_flagController, _site, model) {
    let flagsAvailable = model.flagsAvailable;

    // "message user" option should be at the top
    const notifyUserIndex = flagsAvailable.indexOf(
      flagsAvailable.filterBy("name_key", "notify_user")[0]
    );

    if (notifyUserIndex !== -1) {
      const notifyUser = flagsAvailable[notifyUserIndex];
      flagsAvailable.splice(notifyUserIndex, 1);
      flagsAvailable.splice(0, 0, notifyUser);
    }

    return flagsAvailable;
  }

  postActionFor(controller) {
    return controller
      .get("model.actions_summary")
      .findBy("id", controller.get("selected.id"));
  }
}
