import { tracked } from "@glimmer/tracking";
import { meta } from "@ember/-internals/meta";
import { isArray } from "@ember/array";
import {
  defineProperty,
  get,
  getProperties,
  notifyPropertyChange,
  set,
} from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import ObjectProxy from "@ember/object/proxy";

const hasOwnProp = Object.prototype.hasOwnProperty;

function isEmpty(obj) {
  for (const key in obj) {
    if (hasOwnProp.call(obj, key)) {
      return false;
    }
  }
  return true;
}

/**
 * An `ObjectProxy` which holds writes in a buffer until they are applied to the
 * underlying `content`, so edits can be discarded without touching the original.
 */
export default class BufferedProxy extends ObjectProxy {
  @tracked hasBufferedChanges;

  init() {
    this.initializeBuffer();
    set(this, "hasBufferedChanges", false);
    super.init(...arguments);
  }

  @dependentKeyCompat
  get hasChanges() {
    return this.hasBufferedChanges;
  }

  initializeBuffer(onlyTheseKeys) {
    if (isArray(onlyTheseKeys) && !isEmpty(onlyTheseKeys)) {
      onlyTheseKeys.forEach((key) => delete this.buffer[key]);
    } else {
      set(this, "buffer", Object.create(null));
    }
  }

  unknownProperty(key) {
    const buffer = get(this, "buffer");

    return hasOwnProp.call(buffer, key)
      ? buffer[key]
      : super.unknownProperty(key);
  }

  setUnknownProperty(key, value) {
    const m = meta(this);

    // A prototype or still-initializing object has no buffer to delegate to.
    if (m.proto === this || (m.isInitializing && m.isInitializing())) {
      defineProperty(this, key, null, value);
      return value;
    }

    const { buffer, content } = getProperties(this, ["buffer", "content"]);
    const current = content == null ? undefined : get(content, key);
    const previous = hasOwnProp.call(buffer, key) ? buffer[key] : current;

    if (previous === value) {
      return;
    }

    if (current === value) {
      delete buffer[key];
      if (isEmpty(buffer)) {
        set(this, "hasBufferedChanges", false);
      }
    } else {
      buffer[key] = value;
      set(this, "hasBufferedChanges", true);
    }

    notifyPropertyChange(this, key);

    return value;
  }

  applyBufferedChanges(onlyTheseKeys) {
    const { buffer, content } = getProperties(this, ["buffer", "content"]);

    for (const key of Object.keys(buffer)) {
      if (isArray(onlyTheseKeys) && !onlyTheseKeys.includes(key)) {
        continue;
      }

      set(content, key, buffer[key]);
    }

    this.initializeBuffer(onlyTheseKeys);

    if (isEmpty(get(this, "buffer"))) {
      set(this, "hasBufferedChanges", false);
    }
  }

  discardBufferedChanges(onlyTheseKeys) {
    const buffer = get(this, "buffer");

    this.initializeBuffer(onlyTheseKeys);

    for (const key of Object.keys(buffer)) {
      if (isArray(onlyTheseKeys) && !onlyTheseKeys.includes(key)) {
        continue;
      }

      notifyPropertyChange(this, key);
    }

    if (isEmpty(get(this, "buffer"))) {
      set(this, "hasBufferedChanges", false);
    }
  }

  applyChanges(...args) {
    return this.applyBufferedChanges(...args);
  }

  discardChanges(...args) {
    return this.discardBufferedChanges(...args);
  }

  /** Whether a single key differs from `content`, rather than the whole buffer. */
  hasChanged(key) {
    const { buffer, content } = getProperties(this, ["buffer", "content"]);

    if (typeof key !== "string" || typeof get(buffer, key) === "undefined") {
      return false;
    }

    return get(buffer, key) !== get(content, key);
  }
}
