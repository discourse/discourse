import { getOwner as emberGetOwner, setOwner } from "@ember/application";
import deprecated from "discourse-common/lib/deprecated";

let _default = {};

/**
 * Works similarly to { getOwner } from `@ember/application`, but has a fallback
 * when the passed object doesn't have an owner.
 *
 * This exists for historical reasons. Ideally, any uses of it should be updated to use
 * the official `@ember/application` implementation.
 */
export function getOwnerWithFallback(obj) {
  if (emberGetOwner) {
    return emberGetOwner(obj || _default) || emberGetOwner(_default);
  }

  return obj.container;
}

const GET_OWNER_DEPRECATION_MESSAGE = `
Importing getOwner from \`discourse-common/lib/get-owner\` is deprecated.

* In API initializers you have the access to \`api.container\`:
  \`\`\`
  apiInitializer("1.0", (api) => {
    const router = api.container.lookup("service:router");
  \`\`\`
* In components/controllers/routes you should use service injections:
  \`\`\`
  import { inject as service } from "@ember/service";
  export default class Something extends Component {
    @service router;
  \`\`\`
* In cases where a service can be unavailable (i.e. it comes from an optional plugin)
  There's \`optionalService\` injection:
  \`\`\`
  import optionalService from "discourse/lib/optional-service";
  export default class Something extends Component {
    @optionalService categoryBannerPresence;
  \`\`\`
* And for a direct replacement, you can use  \`import { getOwner } from '@ember/application'\`,
  or if you still need the fallback shim (in non-component/controller/route context),
  use \`import { getOwnerWithFallback } from 'discourse-common/lib/get-owner';\`.
`.trim();

/**
 * @deprecated use `getOwnerWithFallback` instead
 */
export function getOwner(obj) {
  deprecated(GET_OWNER_DEPRECATION_MESSAGE, {
    since: "3.2",
    id: "discourse.get-owner-with-fallback",
  });
  return getOwnerWithFallback(obj);
}

export function setDefaultOwner(container) {
  setOwner(_default, container);
}

// `this.container` is deprecated, but we can still build a container-like
// object for components to use
export function getRegister(obj) {
  const owner = getOwnerWithFallback(obj);
  const register = {
    lookup: (...args) => owner.lookup(...args),
    lookupFactory: (...args) => {
      if (owner.factoryFor) {
        return owner.factoryFor(...args);
      } else if (owner._lookupFactory) {
        return owner._lookupFactory(...args);
      }
    },

    deprecateContainer(target) {
      Object.defineProperty(target, "container", {
        get() {
          deprecated(
            "Use `this.register` or `getOwner` instead of `this.container`",
            { id: "discourse.this-container" }
          );
          return register;
        },
      });
    },
  };

  setOwner(register, owner);

  return register;
}
