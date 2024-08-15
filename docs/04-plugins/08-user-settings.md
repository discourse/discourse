---
title: Add a custom per-user setting in a plugin
short_title: User settings
id: user-settings

---
I just went through this process and experienced a bunch of trial and error, so I thought I'd document my findings to help the next developer to come along.

The things I needed:
- Register your custom field type (mine was boolean, default is string)
  ```ruby
  # plugin.rb
  User.register_custom_field_type 'my_preference', :boolean
  ```
- Register that the custom field should be editable by users. Syntax matches that of [`params.permit(...)`
](https://edgeapi.rubyonrails.org/classes/ActionController/Parameters.html#method-i-permit)
  ```ruby
  # plugin.rb
  register_editable_user_custom_field :my_preference # Scalar type (string, integer, etc.)
  register_editable_user_custom_field [:my_preference , my_preference : []] # For array type
  register_editable_user_custom_field [:my_preference,  my_preference : {}] # for json type
  ```
- Add them to the fields serialized with the CurrentUserSerializer
  ```ruby
  # plugin.rb
  DiscoursePluginRegistry.serialized_current_user_fields << 'my_preference'
  ```
- Create a component to display your user preference
  ```xml
  // assets/javascripts/discourse/templates/components/my-preference.hbs
  <label class="control-label">My custom preferences!</label>
  {{preference-checkbox labelKey="my_plugin.preferences.key" checked=user.custom_fields.my_preference}}
  ```

- Connect that component to one of the preferences plugin outlets (mine was under 'interface' in the user preferences)
  ```
  # assets/javascripts/discourse/connectors/user-preferences-interface/my-preference.hbs
  {{my-preference user=model}}
  ```
- Ensure 'custom fields' are saved on that preferences tab
  ```js
  import { withPluginApi } from 'discourse/lib/plugin-api'
  
  export default {
    name: 'post-read-email',
    initialize () {
       withPluginApi('0.8.22', api => {
  
         api.modifyClass('controller:preferences/emails', {
           actions: {
             save () {
               this.get('saveAttrNames').push('custom_fields')
               this._super()
             }
           }
         })
  
       })
    }
  }
  ```
