/* eslint-disable no-console */
const BrowserTestRunner = require("testem/lib/runners/browser_test_runner");

function labelForRunner(runner) {
  const testPage = runner?.launcher?.settings?.test_page || "";
  const url = new URL(testPage, "http://localhost");

  // Plugins
  const target = url.searchParams.get("target");
  if (target && target !== "core") {
    return target;
  }

  // load-balanced ember-exam:
  const browser = url.searchParams.get("browser");
  if (browser) {
    return `Browser ${browser}`;
  }

  // Themes / non-parallel core
  return "log";
}

let patched = false;

module.exports = function patchTestemOutput() {
  if (patched) {
    return;
  }
  patched = true;

  const originalTryAttach = BrowserTestRunner.prototype.tryAttach;
  BrowserTestRunner.prototype.tryAttach = function (browser, id, socket) {
    const result = originalTryAttach.call(this, browser, id, socket);
    if (result === false) {
      return result;
    }

    const label = labelForRunner(this);
    socket.on("browser-console", (type, ...args) => {
      if (type === "group") {
        type = `「group」`;
      } else {
        type = `[${type}]`;
      }

      console.log(`[${label}] ${type} ${args.join(" ")}`);
    });
    socket.on("top-level-error", (msg, url, line) => {
      console.log(`[${label}] [error] ${msg} at ${url}:${line}`);
    });

    return result;
  };
};
