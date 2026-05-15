/* eslint no-console: "off" */

const args = process.argv.slice(2);

if (args.length < 1 || args.length > 2) {
  console.log("Expecting: node test/smoke-test.mjs {URL}");
  process.exit(1);
}

const url = args[0];

console.log(`Starting Discourse Smoke Test for ${url}`);

import path from "path";
import { chromium } from "playwright";

(async () => {
  const browser = await chromium.launch({
    channel: "chrome",
    // when debugging locally setting the SHOW_BROWSER env variable can be very helpful
    headless: process.env.SHOW_BROWSER === undefined,
    args: ["--no-sandbox"],
  });

  const contextOptions = {
    viewport: { width: 1366, height: 768 },
  };

  if (process.env.AUTH_USER && process.env.AUTH_PASSWORD) {
    contextOptions.httpCredentials = {
      username: process.env.AUTH_USER,
      password: process.env.AUTH_PASSWORD,
    };
  }

  const context = await browser.newContext(contextOptions);
  const page = await context.newPage();

  page.on("console", (msg) => {
    if (["error", "warning"].includes(msg.type())) {
      console.log(`PAGE ${msg.type().toUpperCase()}: ${msg.text()}`);
    }
  });
  page.on("pageerror", (err) => console.log(`PAGE ERROR: ${err.message}`));

  const takeFailureScreenshot = function () {
    const screenshotPath = `${
      process.env.SMOKE_TEST_SCREENSHOT_PATH || "tmp/smoke-test-screenshots"
    }/smoke-test-${Date.now()}.png`;
    console.log(`Screenshot of failure taken at ${screenshotPath}`);
    return page.screenshot({ path: screenshotPath, fullPage: true });
  };

  const exec = (description, fn, assertion) => {
    const start = +new Date();

    return fn
      .call()
      .then(async (output) => {
        if (assertion) {
          if (assertion.call(this, output)) {
            console.log(`PASSED: ${description} - ${+new Date() - start}ms`);
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

  const assert = (description, fn, assertion) => {
    return exec(description, fn, assertion);
  };

  page.on("console", (msg) => console.log(`PAGE LOG: ${msg.text()}`));

  page.on("response", (resp) => {
    if (![200, 204, 302].includes(resp.status())) {
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

  const login = async function () {
    await exec("open login modal or page", () => {
      return page.click(".login-button");
    });

    await exec("login form is visible", () => {
      return page.waitForSelector("#login-form", { state: "visible" });
    });

    await exec("type in credentials & log in", async () => {
      await page
        .locator("#login-account-name")
        .pressSequentially(process.env.DISCOURSE_USERNAME || "smoke_user");

      await page
        .locator("#login-account-password")
        .pressSequentially(process.env.DISCOURSE_PASSWORD || "P4ssw0rd");

      return page.click("#login-button");
    });

    await exec("is logged in", () => {
      return page.waitForSelector(".current-user", { state: "visible" });
    });
  };

  await exec("go to site", () => {
    return page.goto(url);
  });

  await exec("expect a log in button in the header", () => {
    return page.waitForSelector("header .login-button", { state: "visible" });
  });

  if (process.env.LOGIN_AT_BEGINNING) {
    await login();
  }

  await exec("go to latest page", () => {
    return page.goto(path.join(url, "latest"));
  });

  await exec("at least one topic shows up", () => {
    return page.waitForSelector(".topic-list tbody tr", { state: "visible" });
  });

  await exec("go to categories page", () => {
    return page.goto(path.join(url, "categories"));
  });

  await exec("can see categories on the page", () => {
    return page.waitForSelector(".category-list", { state: "visible" });
  });

  await exec("navigate to 1st topic", () => {
    return page.click(".main-link a.title:first-of-type");
  });

  await exec("at least one post body", () => {
    return page.waitForSelector(".topic-post", { state: "visible" });
  });

  await exec("click on the 1st user", () => {
    return page.click(".topic-meta-data a:first-of-type");
  });

  await exec("user has details", () => {
    return page.waitForSelector(".user-card .names", { state: "visible" });
  });

  if (!process.env.READONLY_TESTS) {
    if (!process.env.LOGIN_AT_BEGINNING) {
      await login();
    }

    await exec("go home", async () => {
      await page.waitForSelector("#site-logo, #site-text-logo", {
        state: "visible",
      });

      return page.click("#site-logo, #site-text-logo");
    });

    await exec("it shows a topic list", () => {
      return page.waitForSelector(".topic-list", { state: "visible" });
    });

    await exec("we have a create topic button", () => {
      return page.waitForSelector("#create-topic", { state: "visible" });
    });

    await exec("open composer", () => {
      return page.click("#create-topic");
    });

    await exec("the editor is visible", () => {
      return page.locator("#reply-title:focus").waitFor();
    });

    await page.evaluate(() => {
      document.getElementById("reply-title").value = "";
    });

    await exec("composer is open", () => {
      return page.waitForSelector("#reply-control .d-editor-input", {
        state: "visible",
      });
    });

    await exec("compose new topic", async () => {
      const date = `(${+new Date()})`;
      const title = `This is a new topic ${date}`;
      const post = `I can write a new topic inside the smoke test! ${date} \n\n`;

      await page.locator("#reply-title").pressSequentially(title);

      return page
        .locator("#reply-control .d-editor-input")
        .pressSequentially(post);
    });

    // await exec("updates preview", () => {
    //   return page.waitForSelector(".d-editor-preview p", { state: "visible" });
    // });

    await exec("submit the topic", () => {
      return page.click(".submit-panel .create");
    });

    await exec("topic is created", () => {
      return page.waitForSelector(".fancy-title", { state: "visible" });
    });

    await exec("open the composer", () => {
      return page.click(".post-controls:first-of-type .create");
    });

    await exec("composer is open", () => {
      return page.waitForSelector("#reply-control .d-editor-input", {
        state: "visible",
      });
    });

    await exec("compose reply", () => {
      const post = `I can even write a reply inside the smoke test ;) (${+new Date()})`;
      return page
        .locator("#reply-control .d-editor-input")
        .pressSequentially(post);
    });

    // await exec("waiting for the preview", async () => {
    //   await page.waitForSelector("div.d-editor-preview", {
    //     state: "visible",
    //   });
    //   return page.waitForFunction(
    //     "document.querySelector('div.d-editor-preview').innerText.includes('I can even write a reply')"
    //   );
    // });

    await exec("wait a little bit", () => {
      return new Promise((resolve) => setTimeout(resolve, 5000));
    });

    await exec("submit the reply", async () => {
      await page.click("#reply-control .create");

      return page.waitForSelector("#reply-control.closed", {
        state: "attached",
      });
    });

    await assert("reply is created", () => {
      return page
        .locator(".topic-post:not(.staged) #post_2 .cooked", {
          hasText: "I can even write a reply",
        })
        .waitFor();
    });

    await exec("wait a little bit", () => {
      return new Promise((resolve) => setTimeout(resolve, 5000));
    });

    await exec("open composer to edit first post", async () => {
      await page.evaluate(() => {
        window.scrollTo(0, 0);
      });

      await page.click("#post_1 .post-controls .edit");

      return page.waitForSelector("#reply-control .d-editor-input", {
        state: "visible",
      });
    });

    await exec("update post raw in composer", async () => {
      await new Promise((resolve) => setTimeout(resolve, 5000));

      return page
        .locator("#reply-control .d-editor-input")
        .pressSequentially("\n\nI edited this post");
    });

    await exec("submit the edit", async () => {
      await page.click("#reply-control .create");

      return page.waitForSelector("#reply-control.closed", {
        state: "attached",
      });
    });

    await assert("edit is successful", () => {
      return page
        .locator(".topic-post:not(.staged) #post_1 .cooked", {
          hasText: "I edited this post",
        })
        .waitFor();
    });
  }

  await exec("close browser", () => {
    return browser.close();
  });

  console.log("ALL PASSED");
})();
