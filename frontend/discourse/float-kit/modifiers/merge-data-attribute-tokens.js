import { registerDestructor } from "@ember/destroyable";
import Modifier from "ember-modifier";

function tokenize(value) {
  return value?.split(/\s+/).filter(Boolean) ?? [];
}

export default function mergeDataAttributeTokens(attributeName) {
  return class MergeDataAttributeTokens extends Modifier {
    #element = null;
    #appliedMirrorTargetTokens = [];
    #mirrorResolver = null;
    #mirrorTarget = null;
    #mirrorTargetTokens = [];
    #mirroredTokens = [];
    #observer = null;
    #previousConsumerTokens = [];
    #previousExtraTokens = [];
    #targetObserver = null;

    constructor(owner, args) {
      super(owner, args);
      registerDestructor(this, (instance) => instance.#cleanup());
    }

    modify(element, positional, { mirrorTargetTokens = "", mirrorTo = null }) {
      if (element !== this.#element) {
        this.#disconnectObserver();
        this.#disconnectTargetObserver();
        this.#detachMirrorTarget();
        this.#previousConsumerTokens = [];
        this.#previousExtraTokens = [];
        this.#element = element;
      }

      const consumerTokensOverride =
        mirrorTo && this.#observer?.takeRecords().length
          ? tokenize(element.getAttribute(attributeName))
          : null;
      this.#mirrorResolver = mirrorTo;
      this.#mirrorTargetTokens = tokenize(mirrorTargetTokens);
      this.#mergeTokens(
        element,
        this.#extraTokens(positional),
        consumerTokensOverride
      );

      this.#observeElement(element);
    }

    #extraTokens(positional) {
      return tokenize(positional.flat().filter(Boolean).join(" "));
    }

    #mergeTokens(element, extraTokens, consumerTokensOverride = null) {
      const consumerTokens =
        consumerTokensOverride ?? this.#deriveConsumerTokens(element);
      const mergedTokens = [...new Set([...consumerTokens, ...extraTokens])];

      this.#writeTokens(element, mergedTokens);

      this.#previousConsumerTokens = consumerTokens;
      this.#previousExtraTokens = extraTokens;
      this.#syncMirroredTokens(
        this.#resolveMirrorTarget(element),
        consumerTokens
      );
    }

    #deriveConsumerTokens(element) {
      const previousTokenSet = new Set(this.#previousExtraTokens);
      const previousConsumerTokenSet = new Set(this.#previousConsumerTokens);

      return tokenize(element.getAttribute(attributeName)).filter(
        (token) =>
          !previousTokenSet.has(token) || previousConsumerTokenSet.has(token)
      );
    }

    #resolveMirrorTarget(element) {
      return typeof this.#mirrorResolver === "function"
        ? this.#mirrorResolver(element)
        : this.#mirrorResolver;
    }

    #syncMirroredTokens(target, consumerTokens) {
      if (target !== this.#mirrorTarget) {
        this.#disconnectTargetObserver();
        this.#detachMirrorTarget();
        this.#mirrorTarget = target;
      }

      if (!target) {
        return;
      }

      this.#mirroredTokens = [...new Set(consumerTokens)];
      this.#applyMirroredTokens(target);
      this.#observeTarget(target);
    }

    #applyMirroredTokens(target) {
      this.#writeTokens(target, [
        ...new Set([...this.#mirrorTargetTokens, ...this.#mirroredTokens]),
      ]);
      this.#appliedMirrorTargetTokens = this.#mirrorTargetTokens;
    }

    #detachMirrorTarget() {
      if (!this.#mirrorTarget) {
        return;
      }

      this.#writeTokens(this.#mirrorTarget, this.#appliedMirrorTargetTokens);
      this.#appliedMirrorTargetTokens = [];
      this.#mirrorTarget = null;
      this.#mirroredTokens = [];
    }

    #writeTokens(element, tokens) {
      const value = tokens.join(" ");
      const currentValue = element.getAttribute(attributeName) ?? "";

      if (value === currentValue) {
        return;
      }

      if (value) {
        element.setAttribute(attributeName, value);
      } else {
        element.removeAttribute(attributeName);
      }

      if (element === this.#element) {
        this.#observer?.takeRecords();
      }
      if (element === this.#mirrorTarget) {
        this.#targetObserver?.takeRecords();
      }
    }

    #observeElement(element) {
      if (this.#observer) {
        return;
      }

      this.#observer = new MutationObserver(() => {
        this.#mergeTokens(
          element,
          this.#previousExtraTokens,
          this.#mirrorResolver
            ? tokenize(element.getAttribute(attributeName))
            : null
        );
      });
      this.#observer.observe(element, {
        attributeFilter: [attributeName],
      });
    }

    #disconnectObserver() {
      this.#observer?.disconnect();
      this.#observer = null;
    }

    #observeTarget(target) {
      if (this.#targetObserver) {
        return;
      }

      this.#targetObserver = new MutationObserver(() => {
        this.#applyMirroredTokens(target);
      });
      this.#targetObserver.observe(target, {
        attributeFilter: [attributeName],
      });
    }

    #disconnectTargetObserver() {
      this.#targetObserver?.disconnect();
      this.#targetObserver = null;
    }

    #cleanup() {
      this.#disconnectObserver();
      this.#disconnectTargetObserver();
      this.#detachMirrorTarget();
      this.#element = null;
      this.#appliedMirrorTargetTokens = [];
      this.#mirrorResolver = null;
      this.#mirrorTargetTokens = [];
      this.#mirroredTokens = [];
      this.#previousConsumerTokens = [];
      this.#previousExtraTokens = [];
    }
  };
}
