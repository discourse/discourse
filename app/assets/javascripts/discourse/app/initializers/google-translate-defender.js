let observerConnected = false;
let patched = false;

/**
 * Chrome's translation feature is known to break JS-framework-rendered apps.
 * Issue: https://bugs.chromium.org/p/chromium/issues/detail?id=872770
 * This initializer detects when the translation is activated and adds
 * error catching to the relevant node functions.
 *
 * Many things will still be broken, but catching these errors mitigates the worst symptoms.
 *
 * Note: this only helps in production ember builds. In development, failing assertions in
 * Ember/Glimmer will still be triggered.
 */
export default {
  initialize() {
    if (observerConnected) {
      return;
    }

    const observer = new MutationObserver(handleMutation);
    observer.observe(document.documentElement, { attributes: true });

    observerConnected = true;
  },
};

function handleMutation(mutations) {
  for (const mutation of mutations) {
    if (patched || mutation.attributeName !== "class") {
      return;
    }

    const classNames = mutation.target.classList;

    if (
      classNames.contains("translated-ltr") ||
      classNames.contains("translated-rtl")
    ) {
      // eslint-disable-next-line no-console
      console.error(
        "[Google Translate Defender] Detected active translation. This may cause problems due to https://bugs.chromium.org/p/chromium/issues/detail?id=872770. Patching some methods to reduce the severity of issues."
      );

      defendAgainstGoogleTranslate();
      patched = true;
    }
  }
}

// From https://github.com/facebook/react/issues/11538#issuecomment-417504600
function defendAgainstGoogleTranslate() {
  const originalRemoveChild = Node.prototype.removeChild;
  Node.prototype.removeChild = function (child) {
    if (child.parentNode !== this) {
      // eslint-disable-next-line no-console
      console.error(
        "[Google Translate Defender] Caught error: cannot remove a child from a different parent",
        child,
        this
      );

      return child;
    }
    return originalRemoveChild.apply(this, arguments);
  };

  const originalInsertBefore = Node.prototype.insertBefore;
  Node.prototype.insertBefore = function (newNode, referenceNode) {
    if (referenceNode && referenceNode.parentNode !== this) {
      // eslint-disable-next-line no-console
      console.error(
        "[Google Translate Defender] Caught error: Cannot insert before a reference node from a different parent",
        "",
        referenceNode,
        this
      );

      return newNode;
    }
    return originalInsertBefore.apply(this, arguments);
  };
}
