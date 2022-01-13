/*eslint no-console: "off"*/

const args = process.argv.slice(2);

if (args.length < 1 || args.length > 2) {
  console.log("Expecting: node {smoke_test.js} {url}");
  process.exit(1);
}

const url = args[0];

console.log(`Starting Discourse Smoke Test for ${url}`);

const chromeLauncher = require("chrome-launcher");
const puppeteer = require("puppeteer-core");
const path = require("path");

(async () => {
  const browser = await puppeteer.launch({
    executablePath: chromeLauncher.Launcher.getInstallations()[0],
    // when debugging locally setting the SHOW_BROWSER env variable can be very helpful
    headless: process.env.SHOW_BROWSER === undefined,
    args: ["--disable-local-storage", "--no-sandbox"],
  });
  const page = await browser.newPage();

  await page.setViewport({
    width: 1366,
    height: 768
  });

  const takeFailureScreenshot = function() {
    const screenshotPath = `${process.env.SMOKE_TEST_SCREENSHOT_PATH ||
      "tmp/smoke-test-screenshots"}/smoke-test-${Date.now()}.png`;
    console.log(`Screenshot of failure taken at ${screenshotPath}`);
    return page.screenshot({ path: screenshotPath, fullPage: true });
  };

  const exec = (description, fn, assertion) => {
    const start = +new Date();

    return fn
      .call()
      .then(async output => {
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
      .catch(async error => {
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

  page.on("console", msg => console.log(`PAGE LOG: ${msg.text()}`));

  page.on("response", resp => {
    if (resp.status() !== 200 && resp.status() !== 302) {
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

  if (process.env.AUTH_USER && process.env.AUTH_PASSWORD) {
    await exec("basic authentication", () => {
      return page.authenticate({
        username: process.env.AUTH_USER,
        password: process.env.AUTH_PASSWORD
      });
    });
  }

  const login = async function() {
    await exec("open login modal", () => {
      return page.click(".login-button");
    });

    await exec("login modal is open", () => {
      return page.waitForSelector(".login-modal", { visible: true });
    });

    await exec("type in credentials & log in", () => {
      let promise = page.type(
        "#login-account-name",
        process.env.DISCOURSE_USERNAME || "smoke_user"
      );

      promise = promise.then(() => {
        return page.type(
          "#login-account-password",
          process.env.DISCOURSE_PASSWORD || "P4ssw0rd"
        );
      });

      promise = promise.then(() => {
        return page.click(".login-modal .btn-primary");
      });

      return promise;
    });

    await exec("is logged in", () => {
      return page.waitForSelector(".current-user", { visible: true });
    });
  };

  await exec("go to site", () => {
    return page.goto(url);
  });

  await exec("expect a log in button in the header", () => {
    return page.waitForSelector("header .login-button", { visible: true });
  });

  if (process.env.LOGIN_AT_BEGINNING) {
    await login();
  }

  await exec("go to latest page", () => {
    return page.goto(path.join(url, "latest"));
  });

  await exec("at least one topic shows up", () => {
    return page.waitForSelector(".topic-list tbody tr", { visible: true });
  });

  await exec("go to categories page", () => {
    return page.goto(path.join(url, "categories"));
  });

  await exec("can see categories on the page", () => {
    return page.waitForSelector(".category-list", { visible: true });
  });

  await exec("navigate to 1st topic", () => {
    return page.click(".main-link a.title:first-of-type");
  });

  await exec("at least one post body", () => {
    return page.waitForSelector(".topic-post", { visible: true });
  });

  await exec("click on the 1st user", () => {
    return page.click(".topic-meta-data a:first-of-type");
  });

  await exec("user has details", () => {
    return page.waitForSelector(".user-card .names", { visible: true });
  });

  if (!process.env.READONLY_TESTS) {
    if (!process.env.LOGIN_AT_BEGINNING) {
      await login();
    }

    await exec("go home", () => {
      let promise = page.waitForSelector("#site-logo, #site-text-logo", {
        visible: true
      });

      promise = promise.then(() => {
        return page.click("#site-logo, #site-text-logo");
      });

      return promise;
    });

    await exec("it shows a topic list", () => {
      return page.waitForSelector(".topic-list", { visible: true });
    });

    await exec("we have a create topic button", () => {
      return page.waitForSelector("#create-topic", { visible: true });
    });

    await exec("open composer", () => {
      return page.click("#create-topic");
    });

    await exec("the editor is visible", () => {
      return page.waitForFunction(
        "document.activeElement === document.getElementById('reply-title')"
      );
    });

    await page.evaluate(() => {
      document.getElementById("reply-title").value = "";
    });

    await exec("compose new topic", () => {
      const date = `(${+new Date()})`;
      const title = `This is a new topic ${date}`;
      const post = `I can write a new topic inside the smoke test! ${date} \n\n`;

      let promise = page.type("#reply-title", title);

      promise = promise.then(() => {
        return page.type("#reply-control .d-editor-input", post);
      });

      return promise;
    });

    await exec("updates preview", () => {
      return page.waitForSelector(".d-editor-preview p", { visible: true });
    });

    await exec("submit the topic", () => {
      return page.click(".submit-panel .create");
    });

    await exec("topic is created", () => {
      return page.waitForSelector(".fancy-title", { visible: true });
    });

    await exec("open the composer", () => {
      return page.click(".post-controls:first-of-type .create");
    });

    await exec("composer is open", () => {
      return page.waitForSelector("#reply-control .d-editor-input", {
        visible: true
      });
    });

    await exec("compose reply", () => {
      const post = `I can even write a reply inside the smoke test ;) (${+new Date()})`;
      return page.type("#reply-control .d-editor-input", post);
    });

    await exec("waiting for the preview", () => {
      return page.waitForXPath(
        "//div[contains(@class, 'd-editor-preview') and contains(.//p, 'I can even write a reply')]",
        { visible: true }
      );
    });

    await exec("wait a little bit", () => {
      return page.waitFor(5000);
    });

    await exec("submit the reply", () => {
      let promise = page.click("#reply-control .create");

      promise = promise.then(() => {
        return page.waitForSelector("#reply-control.closed", {
          visible: false
        });
      });

      return promise;
    });

    await assert("reply is created", () => {
      let promise = page.waitForSelector(
        ".topic-post:not(.staged) #post_2 .cooked",
        {
          visible: true
        }
      );

      promise = promise.then(() => {
        return page.waitForFunction(
          "document.querySelector('#post_2 .cooked').innerText.includes('I can even write a reply')"
        );
      });

      return promise;
    });

    await exec("wait a little bit", () => {
      return page.waitFor(5000);
    });

    await exec("open composer to edit first post", () => {
      let promise = page.evaluate(() => {
        window.scrollTo(0, 0);
      });

      promise = promise.then(() => {
        return page.click("#post_1 .post-controls .edit");
      });

      promise = promise.then(() => {
        return page.waitForSelector("#reply-control .d-editor-input", {
          visible: true
        });
      });

      return promise;
    });

    await exec("update post raw in composer", () => {
      let promise = page.waitFor(5000);

      promise = promise.then(() => {
        return page.type(
          "#reply-control .d-editor-input",
          "\n\nI edited this post"
        );
      });

      return promise;
    });

    await exec("submit the edit", () => {
      let promise = page.click("#reply-control .create");

      promise = promise.then(() => {
        return page.waitForSelector("#reply-control.closed", {
          visible: false
        });
      });

      return promise;
    });

    await assert("edit is successful", () => {
      let promise = page.waitForSelector(
        ".topic-post:not(.staged) #post_1 .cooked",
        {
          visible: true
        }
      );

      promise = promise.then(() => {
        return page.waitForFunction(
          "document.querySelector('#post_1 .cooked').innerText.includes('I edited this post')"
        );
      });

      return promise;
    });
  }

  await exec("close browser", () => {
    return browser.close();
  });

  console.log("ALL PASSED");
})();
