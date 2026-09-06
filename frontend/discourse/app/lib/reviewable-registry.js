import { dasherize } from "@ember/string";
import ReviewableFlaggedPost from "discourse/components/reviewable/flagged-post";
import ReviewablePost from "discourse/components/reviewable/post";
import ReviewableQueuedPost from "discourse/components/reviewable/queued-post";
import ReviewableUser from "discourse/components/reviewable/user";
import deprecated from "discourse/lib/deprecated";
import { applyValueTransformer } from "discourse/lib/transformer";

const coreLoaders = {
  ReviewableFlaggedPost: () => ReviewableFlaggedPost,
  ReviewablePost: () => ReviewablePost,
  ReviewableQueuedPost: () => ReviewableQueuedPost,
  ReviewableUser: () => ReviewableUser,
};

function registeredLoaderFor(type) {
  return applyValueTransformer(
    "reviewable-component",
    coreLoaders[type] ?? null,
    { type }
  );
}

// Fallback for plugins that ship a component at a conventional path instead of
// registering it via `api.registerReviewableComponent`. Only works when the
// plugin's modules are eagerly define()d.
function legacyComponentName(owner, type) {
  const dasherized = dasherize(type);
  const componentNames = [
    dasherized.replace("reviewable-", "reviewable-refresh/"),
    dasherized.replace("reviewable-", "reviewable/"),
    dasherized,
  ];

  return componentNames.find(
    (name) =>
      owner.hasRegistration(`component:${name}`) ||
      owner.hasRegistration(`template:components/${name}`)
  );
}

/**
 * Resolves the component used to render the given reviewable type.
 *
 * Returns the component class directly when it is available synchronously, or
 * a promise resolving to it when the type was registered with an async loader.
 *
 * @param {import("@ember/owner").default} owner
 * @param {string} type - The reviewable type class name (e.g. "ReviewableUser")
 * @returns {unknown | Promise<unknown> | null}
 */
export function resolveReviewableComponent(owner, type) {
  const loader = registeredLoaderFor(type);

  if (loader) {
    return loader();
  }

  const name = legacyComponentName(owner, type);
  if (name) {
    deprecated(
      `Reviewable components must be registered with api.registerReviewableComponent ("${type}" was resolved from the "${name}" module path)`,
      { id: "discourse.reviewable.legacy-component-lookup" }
    );
    return owner.resolveRegistration(`component:${name}`);
  }

  return null;
}
