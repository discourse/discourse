"use strict";

const express = require("express");
const cleanBaseURL = require("clean-base-url");
const path = require("path");
const fs = require("fs");
const fsPromises = fs.promises;
const { JSDOM } = require("jsdom");
const { Buffer } = require("node:buffer");
const { env } = require("node:process");
const { glob } = require("glob");

async function listDistAssets() {
  const files = await glob("**/*.js", { nodir: true, cwd: "dist/assets" });
  return new Set(files);
}

function updateScriptReferences({
  chunkInfos,
  dom,
  selector,
  attribute,
  baseURL,
  distAssets,
}) {
  const elements = dom.window.document.querySelectorAll(selector);
  const handledEntrypoints = new Set();

  for (const el of elements) {
    const entrypointName = el.dataset.discourseEntrypoint;

    if (handledEntrypoints.has(entrypointName)) {
      el.remove();
      continue;
    }

    let chunks = chunkInfos[`assets/${entrypointName}.js`]?.assets;

    if (!chunks) {
      if (distAssets.has(`${entrypointName}.js`)) {
        chunks = [`assets/${entrypointName}.js`];
      } else {
        // Not an ember-cli asset, do not rewrite
        continue;
      }
    }

    const newElements = chunks.map((chunk) => {
      const newElement = el.cloneNode(true);
      newElement[attribute] = `${baseURL}${chunk}`;
      newElement.dataset.emberCliRewritten = "true";

      return newElement;
    });

    if (
      entrypointName === "discourse" &&
      el.tagName.toLowerCase() === "script"
    ) {
      const liveReload = dom.window.document.createElement("script");
      liveReload.setAttribute("async", "");
      liveReload.src = `${baseURL}ember-cli-live-reload.js`;
      newElements.unshift(liveReload);
    }

    el.replaceWith(...newElements);

    handledEntrypoints.add(entrypointName);
  }
}

async function handleRequest(proxy, baseURL, req, res) {
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

  const csp = response.headers.get("content-security-policy");
  if (csp) {
    const emberCliAdditions = [
      `http://${originalHost}${baseURL}assets/`,
      `http://${originalHost}${baseURL}ember-cli-live-reload.js`,
      `http://${originalHost}${baseURL}_lr/`,
    ].join(" ");

    const newCSP = csp
      .replaceAll(proxy, `http://${originalHost}`)
      .replaceAll("script-src ", `script-src ${emberCliAdditions} `);

    res.set("content-security-policy", newCSP);
  }

  const contentType = response.headers.get("content-type");
  const isHTML = contentType?.startsWith("text/html");

  res.status(response.status);

  if (isHTML) {
    const [responseText, chunkInfoText, distAssets] = await Promise.all([
      response.text(),
      fsPromises.readFile("dist/assets.json", "utf-8"),
      listDistAssets(),
    ]);

    const chunkInfos = JSON.parse(chunkInfoText);

    const dom = new JSDOM(responseText);

    updateScriptReferences({
      chunkInfos,
      dom,
      selector: "script[data-discourse-entrypoint]",
      attribute: "src",
      baseURL,
      distAssets,
    });

    updateScriptReferences({
      chunkInfos,
      dom,
      selector: "link[rel=preload][data-discourse-entrypoint]",
      attribute: "href",
      baseURL,
      distAssets,
    });

    res.send(dom.serialize());
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

    if (!proxy) {
      // eslint-disable-next-line no-console
      console.error(`
Discourse can't be run without a \`--proxy\` setting, because it needs a Rails application
to serve API requests. For example:

  yarn run ember serve --proxy "http://localhost:3000"\n`);
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
          await handleRequest(proxy, baseURL, req, res);
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
          return next();
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
