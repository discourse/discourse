---
title: Creating Routes in Discourse and Showing Data
short_title: Creating routes
id: creating-routes

---
Over time Discourse has grown in complexity and it can be daunting for beginners to understand how data gets all the way from the back end Ruby on Rails application to the Ember.js application in front. 

This tutorial is meant to show the full lifecycle of a request in Discourse and explain the steps necessary if you want to build a new page with its own URL in our application.

### URLs First

I always prefer to start thinking of features in terms of the URLs to access them. For example let’s say we want to build an admin feature that showed the last snack I ate while working on Discourse. A suitable URL for that would be `/admin/snack`

In this case:

- Visiting `/admin/snack` in your browser should show the snack using the “full stack”, in other words the Ember application will be loaded up and it would request the data it needs to display the snack.

- Visiting `/admin/snack.json` should return the JSON data for the snack itself.

### The Server Side (Ruby on Rails)

Let’s start by creating a new [controller](http://guides.rubyonrails.org/action_controller_overview.html) for the snack. 

**app/controllers/admin/snack_controller.rb**
```ruby
class Admin::SnackController < Admin::AdminController

  def index
    render json: { name: "donut", description: "delicious!" }
  end

end
```

In this case we inherit from `Admin::AdminController` to gain all the security checks to make sure the user viewing the controller is an administrator. We just have one more thing to do to before we can access our controller, and that’s to add a line to `config/routes.rb`:

Find the block that looks like this:

```ruby
namespace :admin, constraints: StaffConstraint.new do
  # lots of stuff
end
```

And add this line inside it:

```ruby
get 'snack' => 'snack#index'
```

Once you’re done, you should be able to visit `/admin/snack.json` in your browser and you’ll see JSON for the snack! Our snack API seems to be working :candy: 

Of course, as you build your feature to add more complexity you likely wouldn’t just return hardcoded JSON from a controller like this, you’d query the database and return it that way.


### The Client Side (Ember.js)

If you open up your browser and visit `/admin/snack` (without the .json) you’ll see that Discourse says “Oops! That page doesn’t exist.” — that’s because there’s nothing in our front end Ember application to respond to the route.  Let’s add a [handlebars template](https://guides.emberjs.com/v1.10.0/templates/handlebars-basics/) to show our snack:

**app/assets/javascripts/admin/templates/snack.hbs**
```handlebars
<h1>{{model.name}}</h1>

<hr>

<p>{{model.description}}</p>
```

And, like on the Rails API side we need to wire up the route. Open the file `app/assets/javascripts/admin/routes/admin-route-map.js.es6` and look for the `export default function()` method. Add the following line:

```javascript
this.route('snack');
```

We have one final thing left to do in Ember land, and that’s to have the Ember application perform an AJAX request to fetch our JSON from the server. Let’s create one last file. This will be an [Ember Route](https://guides.emberjs.com/v1.10.0/routing/specifying-a-routes-model/). Its `model()` function will be called when the route is entered, so we’ll make our `ajax` call in there:

**app/assets/javascripts/admin/routes/admin-snack.js.es6**
```javascript
import { ajax } from 'discourse/lib/ajax';

export default Ember.Route.extend({
  model() {
    return ajax('/admin/snack.json');
  }
});
```

Now, you can open your browser to `/admin/snack` and you should see the details of the snack rendered in the page!

### Summary

- Opening your browser to `/admin/snack` boots up the Ember application

- The Ember application router says `snack` should be the route

- The Ember.Route for `snack` makes an AJAX request to `/admin/snack.json`

- The Rails application router says that should be the `admin_snack controller`

- The `admin_snack_controller` returns JSON

- The Ember application gets the JSON and renders the Handlebars template  

### Where to go from here

I've written a follow up tutorial on [how to add an Ember Component](https://meta.discourse.org/t/adding-ember-components-to-discourse/48891) to Discourse.
