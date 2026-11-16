---
title: Write acceptance tests for Ember code in Discourse
short_title: Acceptance tests
id: acceptance-tests
---

Automated tests are a great way to protect your code against future regressions. Many people are familiar with how to do this in our Rails codebase with [rspec](http://rspec.info/), but the Javascript side can be somewhat of an enigma to some.

Fortunately, it’s pretty easy these days to add basic tests to your Ember code!

For component tests, see [Component tests](33-component-tests.md).

### Acceptance Tests

[Acceptance tests](https://guides.emberjs.com/release/testing/acceptance/) are often easier to write, and can be more powerful than component tests as they test your application the same way a user would in their browser. I often start with acceptance tests, and then if I am making a complicated component I’ll add tests for it too.

Here’s how we can write an acceptance test that will visit our `/admin/snack` route and confirm that the snack was rendered:

**test/javascripts/acceptance/snack-test.js**

```js
import { acceptance } from "helpers/qunit-helpers";
acceptance("Snack");

test("Visit Page", function (assert) {
  visit("/admin/snack");
  andThen(() => {
    assert.ok(exists(".fancy-snack-title"), "the snack title is present");
  });
});
```

The `test()` in this case almost reads like English! The first command says visit the URL of `/admin/snack`. After that, there is an `andThen()` method. This method is necessary to make sure that all the background work is finished before the tests continue. Since Javascript and Ember code is asynchronous, we need to make sure Ember is done everything it needs to do before our assertions are executed. Finally, it tests to see if the `.fancy-snack-title` element is present.

However, if you run this test by visiting `/qunit?module=Acceptance%3A%20Snack` you’ll find that the test will fail, due to an AJAX error.

If you recall, our code includes both a Rails side and a Javascript side which performed an AJAX request to get its data. The acceptance test ran the Javascript side, but it didn’t know what to do to get its data from Rails.

To fix this, we need to add a fake response, using the excellent [pretender](https://github.com/pretenderjs/pretender) library. Open up the `test/javascripts/helpers/create-pretender.js` file and look for the line that says:

```js
this.get("/admin/plugins", () => response({ plugins: [] }));
```

Right below it, add a line to return a fake snack object for our acceptance test to work with:

```js
this.get("/admin/snack.json", () => {
  return response({ name: "snack name", description: "snack description" });
});
```

You can read the above code as "for any request to `/admin/snack.json`, respond with the following `response`."

If you refresh the URL `/qunit?module=Acceptance%3A%20Snack`, your acceptance test should retrieve its data via pretender and the tests should pass.

### Where to go from here

You might try building out a small feature, and adding tests to make sure it works. You could even try using [TDD](https://en.wikipedia.org/wiki/Test-driven_development) by creating your tests before you write any code on the front end. Depending on what you’re working on and your personal preferences, you might find this a more enjoyable way to go about this. Good luck and happy coding :)
