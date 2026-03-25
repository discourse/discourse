import UserActivityAppreciations from "discourse/routes/user-activity/appreciations";

export default class UserNotificationsAppreciationsReceived extends UserActivityAppreciations {
  templateName = "user-activity/appreciations";

  get direction() {
    return "received";
  }
}
