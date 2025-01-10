export default {
  viewingActionType(userActionType) {
    this.controllerFor("user-activity").set("userActionType", userActionType);
  },
};
