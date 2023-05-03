import { getOwner } from "@ember/application";
import EmberObject, { computed } from "@ember/object";

import Controller from "@ember/controller";
import Component from "@ember/component";
import Route from "@ember/routing/route";
import RestModel from "discourse/models/rest";
import RestAdapter from "discourse/adapters/rest";
import Service from "@ember/service";

const disableImplicitInjectionsKey = Symbol("DISABLE_IMPLICIT_INJECTIONS");

/**
 * Based on the Ember's standard injection helper, plus extra logic to make it behave more
 * like Ember<=3 'implicit injections', and to allow disabling it on a per-class basis.
 * https://github.com/emberjs/ember.js/blob/22b318a381/packages/%40ember/-internals/metal/lib/injected_property.ts#L37
 *
 */
function implicitInjectionShim(lookupName, key) {
  let overrideKey = Symbol(`OVERRIDE_${key}`);

  return computed(key, {
    get() {
      if (this[overrideKey]) {
        return this[overrideKey];
      }
      if (this[disableImplicitInjectionsKey]) {
        return undefined;
      }

      let owner = getOwner(this) || this.container;
      if (!owner) {
        return undefined;
      }
      return owner.lookup(lookupName);
    },

    set(_, value) {
      return (this[overrideKey] = value);
    },
  });
}

function setInjections(target, injections) {
  const extension = {};
  for (const [key, lookupName] of Object.entries(injections)) {
    extension[key] = implicitInjectionShim(lookupName, key);
  }
  EmberObject.reopen.call(target, extension);
}

let alreadyRegistered = false;

/**
 * Configure Discourse's standard injections on common framework classes.
 * In Ember<=3 this was done using 'implicit injections', but these have been
 * removed in Ember 4. This shim implements similar behaviour by reopening the
 * base framework classes.
 *
 * Long-term we aim to move away from this pattern, towards 'explicit injections'
 * https://guides.emberjs.com/release/applications/dependency-injection/
 *
 * Incremental migration to newer patterns can be achieved using the `@disableImplicitInjections`
 * helper (availble on `discourse/lib/implicit-injections')
 */
export function registerDiscourseImplicitInjections() {
  if (alreadyRegistered) {
    return;
  }
  const commonInjections = {
    appEvents: "service:app-events",
    pmTopicTrackingState: "service:pm-topic-tracking-state",
    store: "service:store",
    site: "service:site",
    searchService: "service:search",
    session: "service:session",
    messageBus: "service:message-bus",
    siteSettings: "service:site-settings",
    topicTrackingState: "service:topic-tracking-state",
    keyValueStore: "service:key-value-store",
  };

  setInjections(Controller, {
    ...commonInjections,
    capabilities: "service:capabilities",
    currentUser: "service:current-user",
  });

  setInjections(Component, {
    capabilities: "service:capabilities",
    currentUser: "service:current-user",
    ...commonInjections,
  });

  setInjections(Route, {
    ...commonInjections,
    currentUser: "service:current-user",
  });

  setInjections(RestModel, {
    ...commonInjections,
  });

  setInjections(RestAdapter, {
    ...commonInjections,
  });

  setInjections(Service, {
    session: "service:session",
    messageBus: "service:messageBus",
    siteSettings: "service:site-settings",
    topicTrackingState: "service:topic-tracking-state",
    keyValueStore: "service:keyValueStore",
    currentUser: "service:current-user",
  });

  alreadyRegistered = true;
}

/**
 * A class decorator which disables implicit injections for instances of this class.
 * Essentially opts-in to the modern Ember 4+ behaviour.
 */
export function disableImplicitInjections(target) {
  target.prototype[disableImplicitInjectionsKey] = true;
}
