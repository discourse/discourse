export function replaceCurrentUser(properties) {
  const currentUser = Discourse.User.current();
  currentUser.setProperties(properties);
  Discourse.User.resetCurrent(currentUser);
}
