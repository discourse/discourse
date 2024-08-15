---
title: End-to-end system testing for themes and theme components
short_title: E2E testing
id: e2e-testing

---
<div data-theme-toc="true"> </div>

Writing automated tests for themes is an important part of the theme development process which can help ensure that the features being introduced by a theme continues to work well overtime with core Discourse features. 

Currently, Discourse supports two ways of writing regression tests for themes. The first mainly follows [EmberJS's way](https://guides.emberjs.com/release/testing/testing-tools/) and only involves testing the client side code. The second way is to write [Rails system tests](https://guides.rubyonrails.org/v5.1/testing.html#system-testing) which allows you to test both the server side code and client side code at the same time. This document will focus on writing Rails system tests for themes and is what we recommend theme authors focus on when writing tests for their themes as well.

## Rails System tests for themes

Under the hood, Discourse uses the [RSpec](https://rspec.info/) and [Capybara](https://github.com/teamcapybara/capybara) testing frameworks to run [Rails system tests](https://guides.rubyonrails.org/testing.html#system-testing). Basic knowledge about RSpec and Capybara is required to get started and we recommend reading through the following links first before you get started:
* https://github.com/rspec/rspec-core#basic-structure
* https://github.com/teamcapybara/capybara#the-dsl

### Guidelines and tips for writing theme system tests

These are some guidelines to follow when writing system tests: 

* System tests are expected to be located in the `spec/system` directory in the theme's directory. 
* Each file in the `spec/system` directory is expected to follow the `<description_of_system_test>_spec.rb` format. 
* The top level RSpec `describe` block needs the `system: true` metadata to be present. Example: 
    ```rb
    RSpec.describe "Testing A Theme or Theme Component", system: true do
      it "should display the component" do
        ...
      end
    end
    ```
* `upload_theme` and `upload_theme_component` helper methods are available and needs to be called before the tests are ran. Example:
    ```rb
    RSpec.describe "Testing A Theme or Theme Component", system: true do
      let!(:theme) do 
        upload_theme
      end
      
      # or `upload_theme_component` if your theme is a component
      # 
      # let!(:theme_component) do
      #   upload_theme_component
      # end

      it "should display the component" do
        ...
      end
    end
    ``` 
* A theme's setting can be changed in the system test by calling the `update_setting` method on the `theme` object and then saving the theme.

   Example: 
    ```rb
    RSpec.describe "Testing A Theme", system: true do
      let!(:theme) do 
        upload_theme 
      end

      it "should not display the theme when `should_render` theme setting is false" do
        theme.update_setting(:should_render, false)
        theme.save!

        expect(page).not_to have_css("#some-identifier")
      end
    end
    ```

* Discourse uses the [fabrication gem](https://fabricationgem.org/) which allows us to easily setup the test data which we need for each test.   The [full list of fabricators](https://github.com/discourse/discourse/blob/main/spec/fabricators) available in Discourse core can be used in the theme's system test as well. 

    Example: 

    ```ruby
    RSpec.describe "Testing A Theme", system: true do
      let!(:theme) do 
        upload_theme
      end

      it "should display the theme" do
        user = Fabricate(:user)
        category = Fabricate(:category)
        topic = Fabricate(:topic)
        topic_2 = Fabricate(:topic, title: "This is topic number 2")

        ...
      end
    end
    ```

* Use the `sign_in` helper method to test against different user profiles.


    Example: 

    ```ruby
    RSpec.describe "Testing A Theme", system: true do
      let!(:theme) do 
        upload_theme
      end

      it "should not display the theme for a regular user" do
        user = Fabricate(:user)
        sign_in(user)

        ...
      end

      it "should display the theme for a staff user" do
        admin = Fabricate(:admin)
        sign_in(admin)
 
        ...
      end
    end
    ``` 

* Sometimes you'll want to make querying and inspecting parts of the page easier and more reusable for your system tests. To do that you can use the concept of PageObjects, which you'll see done often in [core](https://github.com/discourse/discourse/tree/main/spec/system/page_objects).

    Example:

     ```ruby
     # frozen_string_literal: true
     
     module PageObjects
       module Components
         class MyCustomComponent < PageObjects::Components::Base
           COMPONENT_SELECTOR = ".my-custom-component"
     
           def click_action_button
             find("#{COMPONENT_SELECTOR} .action-button").click
           end
    
           def has_content?(content)
             has_css?("#{COMPONENT_SELECTOR} .content", text: content)
           end
         end
       end
     end
     ```

    and you can then use it by importing it with Ruby's built-in `require_relative` at the top of your system test file.

    ```ruby
    require_relative "page_objects/components/my_custom_component"
   ```


### Running theme system tests

Theme system tests can be run using the [discourse_theme CLI rubygem](https://github.com/discourse/discourse_theme) and can be installed with [these instructions](https://meta.discourse.org/t/install-the-discourse-theme-cli-console-app-to-help-you-build-themes/82950).

Once the `discourse_theme` CLI has been installed, you can run all the system tests in your theme directory by running the following command:

```bash
discourse_theme rspec .
```

On the first run of the `rspec` command for a new theme, you will be prompted on whether you would like to run the system tests using a [local Discourse development environment](https://meta.discourse.org/t/install-discourse-on-ubuntu-or-debian-for-development/14727) or a [Docker](https://docs.docker.com/engine/install/) container which will have the development environment configured for you. Unless you are a seasoned Discourse plugin or theme developer, we recommend selecting `n` and run the tests using a Docker container since everything will just work out of the box. 

The `discourse_theme rspec` command also supports running a single spec directory, file and file with line numbers.

```bash
discourse_theme rspec /path/to/theme/spec/system
discourse_theme rspec /path/to/theme/spec/system/my_system_spec.rb
discourse_theme rspec /path/to/theme/spec/system/my_system_spec.rb:12
```

#### Headful mode
By default, the theme system tests are ran using Google Chrome in the [headless mode](https://developer.chrome.com/blog/headless-chrome/). This is a mode where the browser does not render anything on screen allowing test runs to complete faster. However, it is often useful to be able to see what the system test you have written is doing by using Google Chrome in the headful mode. You can enable this mode by passing the `--headful` option to the `discourse_theme rspec` command.

```bash
discourse_theme rspec . --headful
```

The above command will run the system tests in headful mode where the running of the tests can be seen visually. 

You can also pause the execution of the test in your test case by using the `pause_test` helper method, allowing you to inspect the current state of the application in the browser.

Example: 

```ruby
RSpec.describe "Testing A Theme", system: true do
  let!(:theme) do 
    upload_theme
  end

  it "should display the theme" do
    visit("/")
    click("#some-button")
    pause_test
    ...
  end
end
```
