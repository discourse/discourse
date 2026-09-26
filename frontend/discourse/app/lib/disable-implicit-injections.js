export const disableImplicitInjectionsKey = Symbol(
  "DISABLE_IMPLICIT_INJECTIONS"
);

// A class decorator which opts instances out of Discourse's implicit
// injections, giving them the Ember 4+ behaviour.
export function disableImplicitInjections(target) {
  target.prototype[disableImplicitInjectionsKey] = true;
}
