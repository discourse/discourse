/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import Controller from "@ember/controller";
import EmberObject, { computed } from "@ember/object";
import { getOwner } from "@ember/owner";
import Route from "@ember/routing/route";
import Service from "@ember/service";
import RestAdapter from "discourse/adapters/rest";
import {
  disableImplicitInjections,
  disableImplicitInjectionsKey,
} from "discourse/lib/disable-implicit-injections";
import { lookup } from "discourse/lib/service";
import RestModel from "discourse/models/rest";
import AppEventsService from "discourse/services/app-events";
import CapabilitiesService from "discourse/services/capabilities";
import CurrentUserService from "discourse/services/current-user";
import KeyValueStoreService from "discourse/services/key-value-store";
import MessageBusService from "discourse/services/message-bus";
import PmTopicTrackingStateService from "discourse/services/pm-topic-tracking-state";
import SearchService from "discourse/services/search";
import SessionService from "discourse/services/session";
import SiteService from "discourse/services/site";
import SiteSettingsService from "discourse/services/site-settings";
import StoreService from "discourse/services/store";
import TopicTrackingStateService from "discourse/services/topic-tracking-state";

/**
 * Based on the Ember's standard injection helper, plus extra logic to make it behave more
 * like Ember<=3 'implicit injections', and to allow disabling it on a per-class basis.
 * https://github.com/emberjs/ember.js/blob/22b318a381/packages/%40ember/-internals/metal/lib/injected_property.ts#L37
 *
 */
// Thunks, since the service modules import this one for the disabling decorator.
function implicitInjectionShim(factory, key) {
  let overrideKey = `__OVERRIDE_${key}`;

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
      return lookup(owner, factory());
    },

    set(_, value) {
      return (this[overrideKey] = value);
    },
  });
}

function setInjections(target, injections) {
  const extension = {};
  for (const [key, factory] of Object.entries(injections)) {
    extension[key] = implicitInjectionShim(factory, key);
  }
  EmberObject.reopen.call(target, extension);
  target.proto();
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
 * helper (available on `discourse/lib/implicit-injections')
 */
export function registerDiscourseImplicitInjections() {
  if (alreadyRegistered) {
    return;
  }
  const commonInjections = {
    appEvents: () => AppEventsService,
    pmTopicTrackingState: () => PmTopicTrackingStateService,
    store: () => StoreService,
    site: () => SiteService,
    searchService: () => SearchService,
    session: () => SessionService,
    messageBus: () => MessageBusService,
    siteSettings: () => SiteSettingsService,
    topicTrackingState: () => TopicTrackingStateService,
    keyValueStore: () => KeyValueStoreService,
  };

  setInjections(Controller, {
    ...commonInjections,
    capabilities: () => CapabilitiesService,
    currentUser: () => CurrentUserService,
  });

  setInjections(Component, {
    capabilities: () => CapabilitiesService,
    currentUser: () => CurrentUserService,
    ...commonInjections,
  });

  setInjections(Route, {
    ...commonInjections,
    currentUser: () => CurrentUserService,
  });

  setInjections(RestModel, {
    ...commonInjections,
  });

  setInjections(RestAdapter, {
    ...commonInjections,
  });

  setInjections(Service, {
    session: () => SessionService,
    messageBus: () => MessageBusService,
    siteSettings: () => SiteSettingsService,
    topicTrackingState: () => TopicTrackingStateService,
    keyValueStore: () => KeyValueStoreService,
    currentUser: () => CurrentUserService,
  });

  alreadyRegistered = true;
}

export { disableImplicitInjections };
