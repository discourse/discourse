import ApplicationInstance from "@ember/application/instance";
import { associateDestroyableChild } from "@ember/destroyable";
import { getOwner, setOwner } from "@ember/owner";
import deprecated from "discourse/lib/deprecated";

/**
 * Gives an uploader its parent's owner, and destroys it along with the parent.
 * Passing the owner instead of a parent still works, but is deprecated.
 *
 * @param {object} uploader
 * @param {object} parent The component (or other destroyable) using the uploader
 * @param {object} deprecation
 * @param {string} deprecation.className
 * @param {string} deprecation.id
 */
export default function attachToParent(uploader, parent, { className, id }) {
  if (parent instanceof ApplicationInstance) {
    deprecated(
      `Passing an owner to \`new ${className}()\` is deprecated. Pass the component that uses it instead, so it's torn down with that component.`,
      { id, since: "2026.10.0" }
    );
    setOwner(uploader, parent);
  } else {
    setOwner(uploader, getOwner(parent));
  }

  associateDestroyableChild(parent, uploader);
}
