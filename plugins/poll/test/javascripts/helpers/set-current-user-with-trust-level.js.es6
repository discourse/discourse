export function setCurrentUserWithTrustLevel(trustLevel) {
  const currentUser = Discourse.User.current();
  currentUser.set("trust_level", trustLevel);
  Discourse.User.resetCurrent(currentUser);
}
