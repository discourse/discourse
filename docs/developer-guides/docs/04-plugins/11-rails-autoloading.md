---
title: Structuring a plugin for Rails autoloading
short_title: Rails autoloading
id: rails-autoloading
---

Many plugins include lots of class definitions inside `plugin.rb`, or use `require_relative` to load ruby files. That works, but it comes with some disadvantages:

1. No auto-reloading of changes in development. Any changes require a full server restart
2. Getting the `require` calls in the right order can be painful
3. If they are `require`'d outside the `after_initialize` block, then other autoloaded classes/modules may not be available

There is a solution! Plugins can lean on the standard Rails autoloading system. For new plugins, everything you need is defined in the [plugin-skeleton](https://github.com/discourse/discourse-plugin-skeleton). This topic describes how to adapt an existing plugin and extend the configuration.

## 1. Define a module and a Rails::Engine for your plugin

In `plugin.rb`, define a module for your plugin with a unique `PLUGIN_NAME`, and add a `require_relative` line to load the engine file we're about to create.

```rb
# name: my-plugin-name
# ...

module ::MyPluginModule
  PLUGIN_NAME = "my-plugin-name"
end

require_relative "lib/my_plugin_module/engine"
```

Now create `{plugin}/lib/my_plugin_module/engine.rb`:

```rb
module ::MyPluginModule
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace MyPluginModule
  end
end
```

Important things to note:

1. In plugin.rb, you must include `::` before your module name to define it in the root namespace (otherwise, it would be defined under `Plugin::Instance`)
1. `require_relative "lib/.../engine"` must be in the root of the `plugin.rb` file, not inside an `after_initialize` block

1. Putting the engine in its own file under `lib/` is important. Defining it directly in the `plugin.rb` file will not work. (Rails uses the presence of a `lib/` directory to determine the root of the engine)

1. The file path should include the module name, according to the [Zeitwerk rules](https://github.com/fxn/zeitwerk#file-structure)

1. The `engine_name` is used as the prefix for rake tasks and any routes defined by the engine ([:link: rails docs](https://api.rubyonrails.org/classes/Rails/Engine.html#class-Rails::Engine-label-Engine+name))

1. `isolate_namespace` helps to prevent things leaking between core and the plugin ([:link: Rails docs](https://api.rubyonrails.org/classes/Rails/Engine.html#class-Rails::Engine-label-Isolated+Engine))

## 2. Define ruby files in the correct directory structure

The engine will now autoload all files in `{plugin}/app/{type}/*`. For example, we can define a controller

`{plugin}/app/controllers/my_plugin_module/examples_controller.rb`

```rb
module ::MyPluginModule
  class ExamplesController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    def index
      render json: { hello: "world" }
    end
  end
end
```

This will now be autoloaded whenever anything in Rails tries to access `::MyPluginModule::MyController`. To test things, try accessing that class from the rails console.

For autoloading to work correctly, file paths must match the full module/class hierarchy according to the rules [defined by Zeitwerk](https://github.com/fxn/zeitwerk#file-structure).

## 3. Defining routes on the plugin's engine

Create a `{plugin}/config/routes.rb` file

```rb
MyPluginModule::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw do
  mount ::MyPluginModule::Engine, at: "my-plugin"
end
```

This file will be automatically loaded by the engine, and changes will take effect without a server restart. In this case, the controller action would be available at `/my-plugin/examples.json`.

## 4. Adding more autoloaded paths

Sometimes you may like to introduce additional directories of autoloadable Ruby files. The most common example is the `lib/` directory in a plugin.

Modify your engine definition to append `lib/` to the engine's autoload paths:

```rb
class Engine < ::Rails::Engine
  engine_name PLUGIN_NAME
  isolate_namespace MyPluginModule
  config.autoload_paths << File.join(config.root, "lib")
end
```

Now you can define a lib module like

`{plugin}/lib/my_plugin_module/some_lib_module.rb`

```rb
module ::MyPluginModule::SomeLibModule
end
```

And now any references to `::MyPluginModule::SomeLibModule` will automatically load the module from this file.

## 5. Profit!

All these files will now be automatically loaded without any deliberate `require` calls. Changes will be automatically picked up by rails and reloaded in-place with no server restart.
