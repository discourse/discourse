<h3 align="center">
  <a href="https://github.com/discourse/discourse-automation/blob/main/public/images/discourse-automation.png">
  <img src="https://github.com/discourse/discourse-automation/blob/main/public/images/discourse-automation.png?raw=true" alt="discourse automation Logo" width="200">
  </a>
</h3>

# discourse-automation

discourse-automation is a plugin for to let you automate actions on your discourse Forum

## Installation

Follow [Install a Plugin](https://meta.discourse.org/t/install-a-plugin/19157)
how-to from the official Discourse Meta, using `git clone https://github.com/discourse/discourse-automation.git`
as the plugin command.

## Usage

```ruby
Triggerable.add(:on_cake_day) do
  placeholder(:target_username, 'target_username')

  provided([:target_username])

  field(:group, component: :group)
end
```

### Actions

## Feedback

If you have issues or suggestions for the plugin, please bring them up on
[Discourse Meta](https://meta.discourse.org).
