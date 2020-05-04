export default {
  viewingActionType(userActionType) {
    this.controllerFor("user").set("userActionType", userActionType);
    this.controllerFor("user-activity").set("userActionType", userActionType);
  }
};
