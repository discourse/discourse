---
title: Add Ember Components to Discourse
short_title: Ember components
id: ember-components
---

In the [previous tutorial](https://meta.discourse.org/t/creating-routes-in-discourse-and-showing-data/48827) I showed how to configure both the server and the client side parts of Discourse to respond to a request.

We now recommend you to read the Ember component documentation: https://guides.emberjs.com/v5.8.0/components/introducing-components/

[details="Old tutorial"]
In this tutorial, I’m going to create a new [Ember Component](https://guides.emberjs.com/v2.7.0/components/defining-a-component/) as a way to wrap third party Javascript. This is going to be similar to a [YouTube](https://www.youtube.com/watch?v=S_l_DL8ysQQ) video I made a while back, which you may find informative, only this time it’s specific to Discourse and how we lay out files in our project.

### Why Components?

[Handlebars](http://handlebarsjs.com/) is quite a simple tempting language. It’s just regular HTML along with some dynamic parts. This is simple to learn and great for productivity, but not so great for code re-use. If you’re developing a large application like Discourse, you’ll find that you want to re-use some of the same things over and over.

Components are Ember’s solution to this problem. Let’s create a component that will display our snack in a nicer way.

### Creating a new Component

Components need to have a dash in their name. I’m going to choose `fancy-snack` as the name for this one. Let’s create our template:

**app/assets/javascripts/admin/templates/components/fancy-snack.hbs**

```hbs
<div class="fancy-snack-title">
  <h1>{{snack.name}}</h1>
</div>

<div class="fancy-snack-description">
  <p>{{snack.description}}</p>
</div>
```

Now, to use our component, we will **replace** our existing `admin/snack` template with this:

**app/assets/javascripts/admin/templates/snack.hbs**

```hbs
{{fancy-snack snack=model}}
```

We can now re-use our `fancy-snack` component in any other template, just passing in the model as required.

### Adding Custom Javascript Code

Besides re-usability, Components in Ember are great for safely adding custom Javascript, jQuery and other external code. It gives you control of when the component is inserted into the page, and when it is removed. To do this, we define an [Ember.Component](http://emberjs.com/api/classes/Ember.Component.html) with some code:

**app/assets/javascripts/admin/components/fancy-snack.js**

```js
export default Ember.Component.extend({
  didInsertElement() {
    this._super();
    this.$().animate({ backgroundColor: "yellow" }, 2000);
  },

  willDestroyElement() {
    this._super();
    this.$().stop();
  },
});
```

If you add the above code and refresh the page, you’ll see that our snack has an animation of a slowly fading yellow background.

Let’s explain what’s going on here:

1. When the component is rendered on the page it will call `didInsertElement`

2. The first line of `didInsertElement` (and `willDestroyElement`) is `this._super()` which is necessary because we’re [subclassing Ember.Component](https://guides.emberjs.com/v1.10.0/object-model/classes-and-instances/).

3. The animation is done using [jQuery’s animate](http://api.jquery.com/animate/) function.

4. Finally, the animation is cancelled in the `willDestroyElement` hook, which is called when the component is removed from the page.

You might wonder why we care about `willDestroyElement` at all; the reason is in a long lived Javascript application like Discourse it’s important to clean up after ourselves, lest we leak memory or leave things running. In this case we stop the animation, which tells any jQuery timers that they needn’t fire any more as the component is no longer visible on the page.

[/details]

### Where to go from here

The [final tutorial](https://meta.discourse.org/t/write-ember-acceptance-and-component-tests-for-discourse/49167) in this series covers automated testing.
