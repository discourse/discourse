# Discourse Automation Plugin

discourse-automation is a plugin for to let you automate actions on your discourse Forum

## Usage

```ruby
Triggerable.add(:on_cake_day) do
  placeholder(:target_username, 'target_username')

  provided([:target_username])

  field(:group, component: :group)
end
```

### Endpoints

## Api call

An automation can be triggered through an API call using the top level endpoint: `POST /automations/:automation_id/trigger.json`

An api key will be necessary to make the call:

```ruby
post "/automations/1/trigger.json", {
  params: { context: { foo: :bar } },
  headers: {
    HTTP_API_KEY: "XXX"
  }
}
```

The params of the request will be given as parameter to the automation’s script.

## Feedback

If you have issues or suggestions for the plugin, please bring them up on
[Discourse Meta](https://meta.discourse.org/t/discourse-automation/195773).
