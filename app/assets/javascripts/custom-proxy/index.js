import { HTMLRewriter } from "html-rewriter-wasm";

function updateScriptReferences({
  chunkInfos,
  rewriter,
  selector,
  attribute,
  baseURL,
  distAssets,
}) {
  const handledEntrypoints = new Set();

  rewriter.on(selector, {
    element(element) {
      const entrypointName = element.getAttribute("data-discourse-entrypoint");

      if (handledEntrypoints.has(entrypointName)) {
        element.remove();
        return;
      }

      // let chunks = chunkInfos[`assets/${entrypointName}.js`]?.assets;
      // if (!chunks) {
      //   if (distAssets.has(`${entrypointName}.js`)) {
      //     chunks = [`assets/${entrypointName}.js`];
      //   } else if (entrypointName === "vendor") {
      //     // support embroider-fingerprinted vendor when running with `-prod` flag
      //     const vendorFilename = [...distAssets].find((key) =>
      //       key.startsWith("vendor.")
      //     );
      //     chunks = [`assets/${vendorFilename}`];
      //   } else {
      //     // Not an ember-cli asset, do not rewrite
      //     return;
      //   }
      // }

      const entrypoints = {
        discourse: "/@vite/discourse.js",
        vendor: "/@vite/vendor.js",
        "start-discourse": "/@vite/start-discourse.js",
        // admin: "/@vite/admin.js",
      };

      if (!entrypoints[entrypointName]) {
        return;
      }

      const chunks = [entrypoints[entrypointName]];

      const newElements = chunks.map((chunk) => {
        let newElement = `<${element.tagName}`;

        for (const [attr, value] of element.attributes) {
          if (attr === attribute) {
            newElement += ` ${attribute}="${chunk}"`;
          } else if (value === "") {
            newElement += ` ${attr}`;
          } else {
            newElement += ` ${attr}="${value}"`;
          }
        }

        newElement += ` data-ember-cli-rewritten="true"`;
        newElement += `>`;

        if (element.tagName === "script") {
          newElement += `</script>`;
        }

        return newElement;
      });

      if (
        entrypointName === "discourse" &&
        element.tagName.toLowerCase() === "script"
      ) {
        let nonce = "";
        for (const [attr, value] of element.attributes) {
          if (attr === "nonce") {
            nonce = value;
            break;
          }
        }

        if (!nonce) {
          // eslint-disable-next-line no-console
          console.error(
            "Expected to find a nonce= attribute on the main discourse script tag, but none was found. ember-cli-live-reload may not work correctly."
          );
        }

        // ember-cli-live-reload doesn't select ports correctly, so we use _lr/livereload directly
        // (important for cloud development environments like GitHub CodeSpaces)
        newElements.unshift(
          `<script type="module" src="/@vite/@vite/client" nonce="${nonce}"></script>`
        );
      }

      element.replace(newElements.join("\n"), { html: true });

      handledEntrypoints.add(entrypointName);
    },
  });
}

export default {
  target: "http://localhost:3000",
  headers: {
    "X-Discourse-Ember-CLI": "true",
  },
  configure: (proxy, options) => {
    proxy.on("proxyRes", function (proxyRes, req, res) {
      if (proxyRes.statusMessage) {
        res.statusCode = proxyRes.statusCode;
        res.statusMessage = proxyRes.statusMessage;
      } else {
        res.statusCode = proxyRes.statusCode;
      }

      const resolvedHeaders = {};

      for (let i = 0; i < proxyRes.rawHeaders.length; i += 2) {
        let values = (resolvedHeaders[proxyRes.rawHeaders[i]] ||= []);
        values.push(proxyRes.rawHeaders[i + 1]);
      }

      for (const [header, values] of Object.entries(resolvedHeaders)) {
        res.setHeader(header, values);
      }

      if (proxyRes.headers["content-type"]?.includes("text/html")) {
        const rewriter = new HTMLRewriter((outputChunk) => {
          res.write(outputChunk);
        });

        updateScriptReferences({
          rewriter,
          selector: "script[data-discourse-entrypoint]",
          attribute: "src",
        });

        updateScriptReferences({
          rewriter,
          selector: "link[rel=preload][data-discourse-entrypoint]",
          attribute: "href",
        });

        proxyRes.on("data", function (chunk) {
          rewriter.write(chunk);
        });

        proxyRes.on("end", function () {
          rewriter.end();
          rewriter.free();
          res.end();
        });
      } else {
        proxyRes.pipe(res);
      }
    });
  },
  selfHandleResponse: true,
};
