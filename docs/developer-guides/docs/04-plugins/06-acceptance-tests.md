---
title: Developing Discourse Plugins - Part 6 - Add acceptance tests
short_title: Acceptance tests
id: acceptance-tests-plugins
---

Previous tutorial: https://meta.discourse.org/t/developing-discourse-plugins-part-5-add-an-admin-interface/31761

---

Did you know that Discourse has two large test suites for its code base? On the server side, our Ruby code has a test suite that uses [rspec](https://rspec.info/). For the browser application, we have a [qunit](https://qunitjs.com/) suite that has [ember-testing](https://guides.emberjs.com/release/testing/testing-application/) included.

Assuming you have a development environment set up, if you visit the `http://localhost:4200/tests` URL you will start running the JavaScript test suite in your browser. One fun aspect is that you can see it testing the application in a miniature window in the bottom right corner:

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/6/2/62a63eca67d134def1580fd9fbd84ff62b531ee1.png" width="690" height="481">

The Discourse application is built with **a lot** of tests that will begin running when you visit the `/tests` URL. So it may be helpful to filter your tests by the plugin you are working on. You can do that in the interface by clicking **Plugin** dropdown and selecting your plugin:

![filter plugin|690x92](/assets/acceptance-tests-1.png)

### Adding an Acceptance Test in your Plugin

First, **make sure you have the latest version of Discourse checked out**. Being able to run Acceptance tests from plugins is a relatively new feature, and if you don't check out the latest version your tests won't show up.

For this article I am going to write an acceptance test for the [purple-tentacle](https://github.com/eviltrout/purple-tentacle) plugin that we authored in [part 5](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-5-admin-interfaces/31761) of this series.

Adding an acceptance test is as easy as adding one file to your plugin. Create the following:

**`test/javascripts/acceptance/purple-tentacle-test.js`**

```js
import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";

acceptance("Purple Tentacle", function (needs) {
  needs.settings({ purple_tentacle_enabled: true });
  needs.user();

  test("Purple tentacle button works", async function (assert) {
    await visit("/admin/plugins/purple-tentacle");
    assert.ok(exists("#show-tentacle"), "it shows the purple tentacle button");
    assert.ok(!exists(".tentacle"), "the tentacle is not shown yet");
    await click("#show-tentacle");
    assert.ok(exists(".tentacle"), "the tentacle wants to rule the world!");
  });
});
```

I tried to write the test in a way that is clear, but it might be a little confusing if you've never written an acceptance test before. I **highly** recommend that you [read the Ember docs](https://guides.emberjs.com/release/testing/testing-application/) on acceptance testing as they have a lot of great information.

In each test we write, we need to `assert` something. In our test, we want to make a few assertions to check whether the tentacle is hidden initially and then shown only after clicking the button.

We want to define a set of actions to be taken before an assertion is made. To do that we use the `await` keyword. By using that keyword, we wait for the execution of each asynchronous helper to finish first.

Our first action of importance is: `await visit("/admin/plugins/purple-tentacle");`. This tells our test to navigate to that URL in our application. That URL was the one that displays the tentacle.

After visiting the page where the purple tentacle button appears, we want to check if we can see the button on the page exists and that the tentacle image doesn't exist yet.

That is done by the following assertions:

```js
assert.ok(exists("#show-tentacle"), "it shows the purple tentacle button");
assert.ok(!exists(".tentacle"), "the tentacle is not shown yet");
```

<small>**P.S.** the previous version of the purple-tentacle plugin didn't have the `#show-tentacle` element id in the handlebars template. Check out the latest version to follow along!</small>

Once those tests pass it's time to test the interaction.

The next command is `await click('#show-tentacle');` which tells our testing framework that we want to click the button and show the tentacle.

After we simulate a click on the button, we can check whether the tentacle appears by asserting:

```js
assert.ok(exists(".tentacle"), "the tentacle wants to rule the world!");
```

Not too bad is it? You can try the test yourself by visiting `http://localhost:4200/tests?qunit_single_plugin=purple-tentacle&qunit_skip_core=1` on your development machine. You should very quickly see the purple tentacle appear and all tests will pass.

If you want to run the plugin qunit tests on the command line using PhantomJS, you can run

```
rake plugin:qunit['purple-tentacle']
```

(where `purple-tentacle` is the folder name of your plugin)

### Debugging your tests

As you write your plugins, your tests can help you identify issues in your plugin. When you're developing your tests or if you make changes to your plugin's code, the tests may fail. To help understand why, Ember has some nice helpers: `pauseTest()` and `resumeTest()`.

To make use of them, add `await pauseTest()` within your test code where you would like the test to pause. Now, when you run your test in the browser, the test will automatically pause at the point you added `pauseTest(). This will give you a chance to inspect the page or view any errors to help debug for issues.

### Where to go from here

I hate to sound like a broken record but the [Ember documentation](https://guides.emberjs.com/release/testing/testing-application/) on testing is excellent. You might also want to see how Discourse tests various functionality by browsing the tests in our [javascript tests directory](https://github.com/discourse/discourse/tree/main/app/assets/javascripts/discourse/tests). We have quite a few examples in there you can learn from.

Happy testing!

---

### More in the series

Part 1: [Plugin Basics](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-1/30515)
Part 2: [Plugin Outlets](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-2-plugin-outlets/31001)
Part 3: [Site Settings](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-3-custom-settings/31115)
Part 4: [git setup](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-4-git-setup/31272)
Part 5: [Admin interfaces](https://meta.discourse.org/t/beginners-guide-to-creating-discourse-plugins-part-5-admin-interfaces/31761)
**Part 6: This topic**
Part 7: [Publish your plugin](https://meta.discourse.org/t/beginner-s-guide-to-creating-discourse-plugins-part-7-publish-your-plugin/101636)
