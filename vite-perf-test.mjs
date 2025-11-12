/* eslint no-console: "off" */

import { Launcher } from "chrome-launcher";
import { execa } from "execa";
import puppeteer from "puppeteer-core";
import stripAnsi from "strip-ansi";

const browser = await puppeteer.launch({
  executablePath: Launcher.getInstallations()[0],
  // when debugging locally setting the SHOW_BROWSER env variable can be very helpful
  headless: false,
  args: ["--no-sandbox"],
});

let page;

async function newPage() {
  page = await browser.newPage();
  page.on("console", (msg) => {
    if (["error", "warning"].includes(msg.type())) {
      console.log(`PAGE ${msg.type().toUpperCase()}: ${msg.text()}`);
    }
  });
  page.on("pageerror", (err) => console.log(`PAGE ERROR: ${err.message}`));
  // page.on("console", (msg) => console.log(`PAGE LOG: ${msg.text()}`));

  page.on("response", (resp) => {
    if (
      resp.status() !== 200 &&
      resp.status() !== 302 &&
      resp.status() !== 304
    ) {
      console.log(
        "FAILED HTTP REQUEST TO " + resp.url() + " Status is: " + resp.status()
      );
      if (resp.status() === 429) {
        const headers = resp.headers();
        console.log("Response headers:");
        Object.keys(headers).forEach((key) => {
          console.log(`${key}: ${headers[key]}`);
        });
      }
    }
    return resp;
  });

  await page.setViewport({
    width: 1366,
    height: 768,
  });
}

const takeFailureScreenshot = function () {
  const screenshotPath = `${
    process.env.SMOKE_TEST_SCREENSHOT_PATH || "tmp/smoke-test-screenshots"
  }/smoke-test-${Date.now()}.png`;
  console.log(`Screenshot of failure taken at ${screenshotPath}`);
  return page.screenshot({ path: screenshotPath, fullPage: true });
};

const exec = (description, fn, assertion) => {
  console.log(description);

  const start = +new Date();

  return fn
    .call()
    .then(async (output) => {
      if (assertion) {
        if (assertion.call(this, output)) {
          // console.log(`PASSED: ${description} - ${+new Date() - start}ms`);
        } else {
          console.log(`FAILED: ${description} - ${+new Date() - start}ms`);
          await takeFailureScreenshot();
          console.log("SMOKE TEST FAILED");
          process.exit(1);
        }
      } else {
        console.log(`PASSED: ${description} - ${+new Date() - start}ms`);
      }
    })
    .catch(async (error) => {
      console.log(
        `ERROR (${description}): ${error.message} - ${+new Date() - start}ms`
      );
      await takeFailureScreenshot();
      console.log("SMOKE TEST FAILED");
      process.exit(1);
    });
};

let server;

async function startVite(args) {
  await newPage();

  const label = `vite ${args}`;
  console.time(label);

  console.log("vite start");
  server = execa({
    cwd: "app/assets/javascripts/discourse",
  })`./node_modules/.bin/vite ${args} --port 0`;

  server.catch((error) => {
    if (error.exitCode !== 143) {
      throw error;
    }
  });

  let appURL;

  await new Promise((resolve) => {
    server.stdout.on("data", (line) => {
      // console.log(line.toString());

      let result = /Local:\s+(https?:\/\/.*)\//g.exec(
        stripAnsi(line.toString())
      );

      if (result) {
        appURL = result[1].replace("/@vite", "");
        resolve();
      }
    });
  });

  await exec("go to site", () => {
    return page.goto(`${appURL}/latest?safe_mode=no_plugins,no_themes`, {
      timeout: 0,
    });
  });

  await exec("wait for network idle", () => {
    return page.waitForNetworkIdle();
  });

  await exec("expect a log in button in the header", () => {
    return page.waitForSelector(".topic-list tbody tr", {
      visible: true,
      timeout: 0,
    });
  });

  console.timeEnd(label);

  await page.close();
  server.kill();
}

try {
  await startVite("--force");
  await startVite("");

  await exec("close browser", () => {
    return browser.close();
  });
} finally {
  server.kill();
}

console.log("ALL PASSED");
