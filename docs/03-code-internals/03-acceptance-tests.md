---
title: Write acceptance tests and component tests for Ember code in Discourse
short_title: Acceptance tests
id: acceptance-tests

---
Automated tests are a great way to protect your code against future regressions. Many people are familiar with how to do this in our Rails codebase with [rspec](http://rspec.info/), but the Javascript side can be somewhat of an enigma to some.

Fortunately, it’s pretty easy these days to add basic tests to your Ember code! 

### Component Tests

In the [previous tutorial](https://meta.discourse.org/t/adding-ember-components-to-discourse/48891) in this series we added a component called `fancy-snack` to display our snack with a fading background. Let’s write a test for it. Create the following file:

**test/javascripts/components/snack-test.js.es6**
```javascript
import componentTest from 'helpers/component-test';

moduleForComponent('fancy-snack', {integration: true});

componentTest('test the rendering', {
  template: '{{fancy-snack snack=testSnack}}',

  setup() {
    this.set('testSnack', {
      name: 'Potato Chips',
      description: 'Now with extra trans fat!'
    });
  },

  test(assert) {
    assert.equal(this.$('.fancy-snack-title h1').text(), 'Potato Chips');
    assert.equal(this.$('.fancy-snack-description p').text(), 'Now with extra trans fat!');
  }
});
```

To run the test, open your browser on your development server to `/qunit?module=component%3Afancy-snack`. Your browser will then perform the component tests and output something like “2 assertions of 2 passed, 0 failed.” 

Note that while on the `/qunit` page you can run other tests. You can simply select a new test from the `Module` dropdown box at the top of the screen.

Let’s step through the test to understand how it works.

The `template` line tells Ember how we’d like to insert our component. It’s the exact same markup you’d use to place the component in a handlebars template so it should be familiar:

```javascript
template: '{{fancy-snack snack=testSnack}}’,
```

Note that it is passing `testSnack` through as the `snack` parameter. That is defined in the `setup()` method:

```javascript
setup() {
  this.set('testSnack', {
    name: 'Potato Chips',
    description: 'Now with extra trans fat!'
  });
},
```

I’ve just put in some dummy data. That’s all we need to do to have Ember render the component. Finally, we have a couple of assertions in the `test()` method:

```javascript
test(assert) {
  assert.equal(this.$('.fancy-snack-title h1').text(), 'Potato Chips');
  assert.equal(this.$('.fancy-snack-description p').text(), 'Now with extra trans fat!');
}
```

If you use `this.$()` you get access to a [jQuery](http://jquery.com/) selector in your template. The assertions here use that selector to grab the value of the snack’s title and snack’s description and compare them with what we expect. If the values match then the assertions will pass and our test is all working.

It’s worth noting that you don’t need to test every little thing in a component like this. You should use some discretion and try to figure out what things in your code are likely to break or cause confusion to other developers down the road. If you test too many things in your template, it will mean it’s a pain for someone else in the future to change it. Just start small, testing the most obvious things, and in time you’ll get the hang of it.

### Acceptance Tests

[Acceptance tests](https://guides.emberjs.com/v1.12.0/testing/acceptance/) are often easier to write, and can be more powerful than component tests as they test your application the same way a user would in their browser. I often start with acceptance tests, and then if I am making a complicated component I’ll add tests for it too. 

Here’s how we can write an acceptance test that will visit our `/admin/snack` route and confirm that the snack was rendered:

**test/javascripts/acceptance/snack-test.js.es6**
```javascript
import { acceptance } from "helpers/qunit-helpers";
acceptance("Snack");

test("Visit Page", function(assert) {
  visit("/admin/snack");
  andThen(() => {
    assert.ok(exists('.fancy-snack-title'), 'the snack title is present');
  });
});
```

The `test()` in this case almost reads like English! The first command says visit the URL of `/admin/snack`. After that, there is an `andThen()` method. This method is necessary to make sure that all the background work is finished before the tests continue. Since Javascript and Ember code is asynchronous, we need to make sure Ember is done everything it needs to do before our assertions are executed. Finally, it tests to see if the `.fancy-snack-title` element is present.

However, if you run this test by visiting `/qunit?module=Acceptance%3A%20Snack` you’ll find that the test will fail, due to an AJAX error.

If you recall, our code includes both a Rails side and a Javascript side which performed an AJAX request to get its data. The acceptance test ran the Javascript side, but it didn’t know what to do to get its data from Rails.

To fix this, we need to add a fake response, using the excellent [pretender](https://github.com/pretenderjs/pretender) library. Open up the `test/javascripts/helpers/create-pretender.js.es6` file and look for the line that says:

```javascript
this.get('/admin/plugins', () => response({ plugins: [] }));
```

Right below it, add a line to return a fake snack object for our acceptance test to work with:

```javascript
this.get('/admin/snack.json', () => {
  return response({ name: 'snack name', description: 'snack description' });
});
```

You can read the above code as "for any request to `/admin/snack.json`, respond with the following `response`."

If you refresh the URL `/qunit?module=Acceptance%3A%20Snack`, your acceptance test should retrieve its data via pretender and the tests should pass.

### Where to go from here

You might try building out a small feature, and adding tests to make sure it works. You could even try using [TDD](https://en.wikipedia.org/wiki/Test-driven_development) by creating your tests before you write any code on the front end. Depending on what you’re working on and your personal preferences, you might find this a more enjoyable way to go about this. Good luck and happy coding :)
