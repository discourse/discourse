import { enqueueRegistration } from "discourse/lib/blocks/-internals/pending";
import {
  _INTERNAL_SOURCE_KEY,
  CORE_SOURCE,
} from "discourse/lib/customization-source";
import { isTesting } from "discourse/lib/environment";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { registerHashtagType } from "discourse/lib/hashtag-type-registry";
import { preventCloaking } from "discourse/lib/plugin-registries/cloaking";
import { addToolbarCallback } from "discourse/lib/plugin-registries/editor-toolbar";
import { registeredTabs } from "discourse/lib/plugin-registries/more-topics-tabs";
import { reportClientError } from "discourse/lib/report-client-error";
import {
  _registerTransformer,
  transformerTypes,
} from "discourse/lib/transformer";
import {
  NON_STREAM_HTML_DECORATOR,
  registerHtmlDecorator,
  STREAM_HTML_DECORATOR,
} from "discourse/ui-kit/d-decorated-html";

export function wrapWithErrorHandler(func, messageKey) {
  return function () {
    try {
      return func.call(this, ...arguments);
    } catch (error) {
      reportClientError(error, messageKey);
      if (isTesting()) {
        throw error;
      }
      return;
    }
  };
}

// The part of the plugin API that core's own initializers use. The full plugin
// API extends this, and only loads when a plugin or theme needs it.
export class CoreApi {
  #source;

  constructor(container, source = CORE_SOURCE) {
    this.container = container;
    this.#source = source;
  }

  get source() {
    return this.#source;
  }

  getCurrentUser() {
    return this._lookupContainer("service:current-user");
  }

  onAppEvent(name, fn) {
    const appEvents = this._lookupContainer("service:app-events");
    appEvents && appEvents.on(name, fn);
  }

  decorateCookedElement(callback, opts) {
    opts = opts || {};

    callback = wrapWithErrorHandler(callback, "broken_decorator_alert");

    registerHtmlDecorator(
      callback,
      opts.onlyStream ? STREAM_HTML_DECORATOR : NON_STREAM_HTML_DECORATOR
    );

    if (!opts.onlyStream) {
      this.onAppEvent("decorate-non-stream-cooked-element", callback);
    }
  }

  onToolbarCreate(callback) {
    addToolbarCallback(callback);
  }

  preventCloak(postId, prevent = true) {
    preventCloaking(postId, prevent);
  }

  registerHashtagType(type, typeClassInstance) {
    registerHashtagType(type, typeClassInstance);
  }

  registerMoreTopicsTab(tab) {
    registeredTabs.push(tab);
  }

  registerValueTransformer(transformerName, valueCallback) {
    return _registerTransformer(
      transformerName,
      transformerTypes.VALUE,
      valueCallback
    );
  }

  registerBlock(blockOrName, factory) {
    if (typeof blockOrName === "string") {
      if (typeof factory !== "function") {
        throw new Error(
          `registerBlock("${blockOrName}", ...) requires a factory function as second argument.`
        );
      }
      enqueueRegistration({
        kind: "block-factory",
        args: [blockOrName, factory],
        source: this.source,
      });
    } else {
      enqueueRegistration({
        kind: "block",
        args: [blockOrName],
        source: this.source,
      });
    }
  }

  registerBlockOutlet(outletName, options) {
    enqueueRegistration({
      kind: "outlet",
      args: [outletName, options],
      source: this.source,
    });
  }

  registerBlockConditionType(ConditionClass) {
    enqueueRegistration({
      kind: "condition-type",
      args: [ConditionClass],
      source: this.source,
    });
  }

  _lookupContainer(path) {
    if (!this.container || this.container.isDestroying) {
      return;
    }

    return this.container.lookup(path);
  }
}

export function withPluginApi(apiCodeCallback, opts) {
  if (typeof arguments[0] === "string") {
    [, apiCodeCallback, opts] = arguments;
  }

  opts = opts || {};

  const api = new CoreApi(
    getOwnerWithFallback(this),
    opts[_INTERNAL_SOURCE_KEY]
  );

  return apiCodeCallback(api, opts);
}
