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

  flagsAvailable(flagModal) {
    let flagsAvailable = flagModal.args.model.flagModel.flagsAvailable;

    flagsAvailable = flagsAvailable.filter((flag) => {
      return flag.applies_to.includes("Post");
    });

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

  postActionFor(flagModal) {
    return flagModal.args.model.flagModel.actions_summary.findBy(
      "id",
      flagModal.selected.id
    );
  }
}
