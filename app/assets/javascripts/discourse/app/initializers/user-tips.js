export default {
  name: "user-tips",
  after: "message-bus",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");
    if (!currentUser) {
      return;
    }

    const messageBus = container.lookup("service:message-bus");
    const site = container.lookup("service:site");

    messageBus.subscribe("/user-tips", function (seenUserTips) {
      currentUser.set("seen_popups", seenUserTips);
      if (!currentUser.user_option) {
        currentUser.set("user_option", {});
      }
      currentUser.set("user_option.seen_popups", seenUserTips);
      (seenUserTips || []).forEach((userTipId) => {
        currentUser.hideUserTipForever(
          Object.keys(site.user_tips).find(
            (id) => site.user_tips[id] === userTipId
          )
        );
      });
    });
  },
};
