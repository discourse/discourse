// Updated to MathJax v3
// by Mark McClure, June 2025
// https://github.com/mcmcclur
// 
// Original plugin by Sam Saffron et al.

import { next } from "@ember/runloop";
import getURLWithCDN from "discourse/lib/get-url";
import loadScript from "discourse/lib/load-script";
import { withPluginApi } from "discourse/lib/plugin-api";

/* global MathJax */

const MathJaxBASE = getURLWithCDN("/plugins/discourse-math/mathjax/es5");
let initializedMathJax = false;

function initMathJax(opts) {
  if (initializedMathJax) {
    return;
  }

  // Configure MathJax
  // The intention of the loader block is to emulate the behavior of
  // MathJax.tex_mml_chtml.js. Using that file directly caused issues
  // with loading AsciiMath later.
  window.MathJax = {
    startup: { typeset: false },
    chtml: { scale: 1.1 },
    loader: {
      paths: { mathjax: MathJaxBASE },
      load: [
        'core', 'input/tex', 'input/mml',
        'output/chtml', 'ui/menu'
      ]
    },
    options: {
      menuOptions: {
        settings: {}
      }
    }
  };

  // Handle user options
  if (opts.zoom_on_click) {
    window.MathJax.options.menuOptions.settings.zoom = "Click";
    window.MathJax.options.menuOptions.settings.zscale = "175%";
  }
  if (opts.enable_accessibility) {
    window.MathJax.options.menuOptions.settings.assistiveMml = true;
  }
  if (opts.enable_asciimath) {
    window.MathJax.loader.load.push('input/asciimath');
  }

  initializedMathJax = true;
}

function ensureMathJax(opts) {
  initMathJax(opts);
  return loadScript(
    "/plugins/discourse-math/mathjax/es5/startup.js"
  );
}


// This function corresponds to the "mathjax" function 
// in the original Discourse Math plugin.
// I've changed the name of the first argument from 
// "elem" to "post", since it's applied to posts,
// not to individual elements.
function apply_mathjax(post, opts) {
  if (!post) {
    return;
  }

  ensureMathJax(opts)
    .then(function () {
      MathJax.startup.promise
        // Process LaTeX .math
        .then(function () {
          const mathNodes = document.querySelectorAll("div.math, span.math");
          const promises = [];

          mathNodes.forEach(function (node) {
            const tex = node.textContent.trim();
            const display = node.tagName.toLowerCase() === "div";
            const p = MathJax.tex2chtmlPromise(tex, { display }).then(function (chtml) {
              node.replaceWith(chtml);
            });
            promises.push(p);
          });
          return Promise.all(promises);
        })

        // Process AsciiMath .asciimath
        // During development, it seemed essential to separate this
        // from the LaTeX processing above.
        .then(function () {
          const mathNodes = document.querySelectorAll("span.asciimath");
          const promises = [];

          mathNodes.forEach(function (node) {
            if (node?.parentElement?.offsetParent !== null) {
              const ascii = node.textContent.trim();
              const p = MathJax.asciimath2chtmlPromise(ascii).then(function (chtml) {
                node.replaceWith(chtml);
              });
              promises.push(p);
            }
          });
          return Promise.all(promises);
        })

        // Ensure that the typesetting is updated
        // If the plugin seems too slow at some point,
        // it might be reasonable to perform this step 
        // every 10 or 20 mathNodes, rather just once.
        .then(function () {
          MathJax.startup.document.clear();
          MathJax.startup.document.updateDocument();
        })
    });
}

function initializeMath(api, discourseMathOptions) {
  api.decorateCookedElement(
    (element) => {
      next(() => {
        apply_mathjax(element, discourseMathOptions);
      });
    },
    { id: "mathjax" }
  );

  if (api.decorateChatMessage) {
    api.decorateChatMessage(
      (element) => {
        apply_mathjax(element, discourseMathOptions);
      },
      {
        id: "mathjax-chat",
      }
    );
  }
}

export default {
  name: "apply-math-mathjax",
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    let discourse_math_opts = {
      zoom_on_click: siteSettings.discourse_math_zoom_on_click,
      enable_accessibility: siteSettings.discourse_math_enable_accessibility,
      enable_asciimath: siteSettings.discourse_math_enable_asciimath,
    };
    if (
      siteSettings.discourse_math_enabled &&
      siteSettings.discourse_math_provider === "mathjax"
    ) {
      withPluginApi(function (api) {
        initializeMath(api, discourse_math_opts);
      });
    }
  },
};