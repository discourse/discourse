export const SYSTEM_ACTOR = "system";
export const ANONYMOUS_ACTOR = "anonymous";

export const ACTOR_KIND = {
  system: "system",
  anonymous: "anonymous",
  user: "user",
};

export function actorKindForValue(value) {
  if (value === ANONYMOUS_ACTOR) {
    return ACTOR_KIND.anonymous;
  }

  if (!value || value === SYSTEM_ACTOR) {
    return ACTOR_KIND.system;
  }

  return ACTOR_KIND.user;
}
