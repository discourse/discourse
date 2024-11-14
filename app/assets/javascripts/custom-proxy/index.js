"use strict";

const express = require("express");
const cleanBaseURL = require("clean-base-url");
const path = require("path");
const fs = require("fs");
const fsPromises = fs.promises;
const { Buffer } = require("node:buffer");
const { env } = require("node:process");
const { glob } = require("glob");
const { HTMLRewriter } = require("html-rewriter-wasm");

async function listDistAssets(outputPath) {
  const files = await glob("**/*.js", {
    nodir: true,
    cwd: `${outputPath}/assets`,
  });
  return new Set(files);
}

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

      let chunks = chunkInfos[`assets/${entrypointName}.js`]?.assets;
      if (!chunks) {
        if (distAssets.has(`${entrypointName}.js`)) {
          chunks = [`assets/${entrypointName}.js`];
        } else if (entrypointName === "vendor") {
          // support embroider-fingerprinted vendor when running with `-prod` flag
          const vendorFilename = [...distAssets].find((key) =>
            key.startsWith("vendor.")
          );
          chunks = [`assets/${vendorFilename}`];
        } else {
          // Not an ember-cli asset, do not rewrite
          return;
        }
      }

      const newElements = chunks.map((chunk) => {
        let newElement = `<${element.tagName}`;

        for (const [attr, value] of element.attributes) {
          if (attr === attribute) {
            newElement += ` ${attribute}="${baseURL}${chunk}"`;
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
          `<script nonce="${nonce}">window.LiveReloadOptions = { "path": "_lr/livereload", "host": location.hostname, "port": location.port || (location.protocol === "https:" ? 443 : 80) }</script>`,
          `<script async src="/_lr/livereload.js" nonce="${nonce}"></script>`
        );
      }

      element.replace(newElements.join("\n"), { html: true });

      handledEntrypoints.add(entrypointName);
    },
  });
}

async function handleRequest(proxy, baseURL, req, res, outputPath) {
  // x-forwarded-host is used in e.g. GitHub CodeSpaces
  let originalHost = req.headers["x-forwarded-host"] || req.headers.host;

  if (env["FORWARD_HOST"] === "true") {
    if (/^localhost(\:|$)/.test(originalHost)) {
      // Can't access default site in multisite via "localhost", redirect to 127.0.0.1
      res.redirect(
        307,
        `http://${originalHost.replace("localhost", "127.0.0.1")}${req.path}`
      );
      return;
    } else {
      req.headers.host = originalHost;
    }
  } else {
    req.headers.host = new URL(proxy).host;
  }

  if (req.headers["Origin"]) {
    req.headers["Origin"] = req.headers["Origin"]
      .replace(req.headers.host, originalHost)
      .replace(/^https/, "http");
  }

  if (req.headers["Referer"]) {
    req.headers["Referer"] = req.headers["Referer"]
      .replace(req.headers.host, originalHost)
      .replace(/^https/, "http");
  }

  let url = `${proxy}${req.path}`;
  const queryLoc = req.url.indexOf("?");
  if (queryLoc !== -1) {
    url += req.url.slice(queryLoc);
  }

  if (req.method === "GET") {
    req.headers["X-Discourse-Ember-CLI"] = "true";
  }

  const { default: fetch } = await import("node-fetch");
  const response = await fetch(url, {
    method: req.method,
    body: /GET|HEAD/.test(req.method) ? null : req.body,
    headers: req.headers,
    redirect: "manual",
  });

  response.headers.forEach((value, header) => {
    if (header === "set-cookie") {
      // Special handling to get array of multiple Set-Cookie header values
      // per https://github.com/node-fetch/node-fetch/issues/251#issuecomment-428143940
      res.set("set-cookie", response.headers.raw()["set-cookie"]);
    } else {
      res.set(header, value);
    }
  });
  res.set("content-encoding", null);

  const location = response.headers.get("location");
  if (location) {
    const newLocation = location.replace(proxy, `http://${originalHost}`);
    res.set("location", newLocation);
  }

  const contentType = response.headers.get("content-type");
  const isHTML = contentType?.startsWith("text/html");

  res.status(response.status);

  if (isHTML) {
    const [responseText, chunkInfoText, distAssets] = await Promise.all([
      response.text(),
      fsPromises.readFile(`${outputPath}/assets.json`, "utf-8"),
      listDistAssets(outputPath),
    ]);

    const chunkInfos = JSON.parse(chunkInfoText);

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    let output = "";
    const rewriter = new HTMLRewriter((outputChunk) => {
      output += decoder.decode(outputChunk);
    });

    updateScriptReferences({
      chunkInfos,
      rewriter,
      selector: "script[data-discourse-entrypoint]",
      attribute: "src",
      baseURL,
      distAssets,
    });

    updateScriptReferences({
      chunkInfos,
      rewriter,
      selector: "link[rel=preload][data-discourse-entrypoint]",
      attribute: "href",
      baseURL,
      distAssets,
    });

    try {
      await rewriter.write(encoder.encode(responseText));
      await rewriter.end();
    } finally {
      rewriter.free();
    }

    res.send(output);
  } else {
    res.send(Buffer.from(await response.arrayBuffer()));
  }
}

module.exports = {
  name: require("./package").name,

  isDevelopingAddon() {
    return true;
  },

  serverMiddleware(config) {
    const app = config.app;
    let { proxy, rootURL, baseURL } = config.options;
    const outputPath = config.options.path ?? config.options.outputPath;

    if (!proxy) {
      // eslint-disable-next-line no-console
      console.error(`
Discourse can't be run without a \`--proxy\` setting, because it needs a Rails application
to serve API requests. For example:

  pnpm ember serve --proxy "http://localhost:3000"\n`);
      throw "--proxy argument is required";
    }

    baseURL = rootURL === "" ? "/" : cleanBaseURL(rootURL || baseURL);

    const rawMiddleware = express.raw({ type: () => true, limit: "100mb" });
    const pathRestrictedRawMiddleware = (req, res, next) => {
      if (this.shouldHandleRequest(req, baseURL)) {
        return rawMiddleware(req, res, next);
      } else {
        return next();
      }
    };

    app.use(
      "/favicon.ico",
      express.static(
        path.join(
          __dirname,
          "../../../../../../public/images/discourse-logo-sketch-small.png"
        )
      )
    );

    app.use(pathRestrictedRawMiddleware, async (req, res, next) => {
      try {
        if (this.shouldHandleRequest(req, baseURL)) {
          await handleRequest(proxy, baseURL, req, res, outputPath);
        } else {
          // Fixes issues when using e.g. "localhost" instead of loopback IP address
          req.headers.host = "127.0.0.1";
        }
      } catch (error) {
        res.send(`
          <html>
            <h1>Discourse Ember CLI Proxy Error</h1>
            <pre><code>${error.stack}</code></pre>
          </html>
        `);
      } finally {
        if (!res.headersSent) {
          next();
        }
      }
    });
  },

  shouldHandleRequest(request, baseURL) {
    if (
      [
        `${baseURL}tests/index.html`,
        `${baseURL}ember-cli-live-reload.js`,
        `${baseURL}testem.js`,
        `${baseURL}assets/test-i18n.js`,
      ].includes(request.path)
    ) {
      return false;
    }

    // All JS assets are served by Ember CLI, except for
    // plugin assets which end in _extra.js
    if (
      request.path.startsWith(`${baseURL}assets/`) &&
      !request.path.endsWith("_extra.js")
    ) {
      return false;
    }

    if (request.path.startsWith(`${baseURL}_lr/`)) {
      return false;
    }

    if (request.path.startsWith(`${baseURL}message-bus/`)) {
      return false;
    }

    return true;
  },
};
