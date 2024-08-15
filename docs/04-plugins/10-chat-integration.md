---
title: Add a new provider to discourse-chat-integration
short_title: Chat integration
id: chat-integration

---
[**discourse-chat-integration**](https://meta.discourse.org/t/chatroom-integration-plugin-discourse-chat-integration/66522) abstracts away the boilerplate for integrating Discourse with external chatroom systems. There are three features which a provider implementation can support: **Notifications**, **Slash Commands** and **Transcripts**.

There are two ways you can add a provider: in your own plugin, or by submitting a pull request to **discourse-chat-integration**. This post will detail the latter, but most of the information will work in either scenario.

This post gives a general overview of how things work, but the best way to understand it is to read the code for existing providers. I have tried to document unusual bits with comments, and am happy to answer questions in this topic :slight_smile: 

## Adding Notification Support :bell: 
1. In the [`Provider` folder](https://github.com/discourse/discourse-chat-integration/tree/master/lib/discourse_chat/provider), create a new folder with the name of your chatroom system: e.g. `hipchat`
2. Create a new ruby file, following the format `hipchat_provider.rb`
3. Within that, define a new module inside `DiscourseChat::Provider`. The name of the module **must** end in `Provider` for it to be loaded correctly. Your module must define three constants:
   - `PROVIDER_NAME`: A string used to reference your provider internally. It shouldn't contain any whitespace. It will likely be the same as the folder name
   - `PROVIDER_ENABLED_SETTING`: A symbol referencing a site setting used to enable/disable this provider. Make sure you define it in the plugin's `settings.yml` file.
   - `CHANNEL_PARAMETERS`: An array of hashes defining what data your provider needs about each channel. This might be a URL, a username, or some kind of 'Channel ID'. Each hash should specify the parameters
       - `key`: the key you will use to reference the data later
       - `regex`: the regular expression used to validate the user-provided value. This is checked both on the client and the server. For example, to only allow non-whitespace characters, you could use `^\S+$`
       - `unique`: (optional) set this to true to stop users creating more than one channel with the same value for this parameter
       - `hidden`: (optional) set this to true to hide this parameter from the list of channels. It will always be shown in the "Edit Channel" modal.

[quote]
:information_source: If your channel parameters are not 'human-readable', you may want to add a "Name" parameter, for the user to enter a more useful channel identifier for their reference. See [the hipchat provider](https://github.com/discourse/discourse-chat-integration/blob/master/lib/discourse_chat/provider/hipchat/hipchat_provider.rb#L7) for an example of this.
[/quote]

4. Your module must also define the function `self.trigger_notification(post, channel)`. Inside this function you should write code to actually send the notification to your chat system. This will vary based on the provider, but will generally consist of sending a `RESTful` request to their API. Try looking at the implementations of [existing providers](https://github.com/discourse/discourse-chat-integration/tree/master/lib/discourse_chat/provider) to help you.
5. Make sure to handle errors returned by your provider's API. You should raise a `DiscourseChat::ProviderError`, and optionally specify a (client side) translation key which gives information about the error. This will be displayed in the admin user interface against the current channel. You can specify additional objects in the `info` hash, which will be included in the site's logs.
6. To make sure Discourse loads your ruby file, you should add a `require_relative` line to the bottom of [provider.rb](https://github.com/discourse/discourse-chat-integration/blob/master/lib/discourse_chat/provider.rb). 

You should end up with something that looks like this:

```ruby
module DiscourseChat::Provider::HipchatProvider

  # This should be unique, and without whitespace
  PROVIDER_NAME = "hipchat".freeze

  # Make sure the referenced setting has been added to settings.yml as a boolean
  PROVIDER_ENABLED_SETTING = :chat_integration_hipchat_enabled

  CHANNEL_PARAMETERS = [
                        { key: "name", regex: '^\S+' }, # Must not start with a space
                        { key: "webhook_url", regex: 'hipchat\.com', unique: true, hidden: true }, # Must contain hipchat.com
                        { key: "color", regex: '^(yellow|green|red|purple|gray|random)$' } # Must be one of these colours
                       ]

  def self.trigger_notification(post, channel)

    # Access the user-defined channel parameters like this
    webhook_url = channel.data['webhook_url']
    color = channel.data['color']

    # The "post" object can be used to get the information to send
    title = post.topic.title
    link_url = post.full_url

    # Post.excerpt has a number of options you can use to format nicely before sending to your chat system
    # Most of the time, you'll want remap_emojis to convert discourse emojis to unicode
    excerpt = post.excerpt(400, text_entities: true, strip_links: true, remap_emoji: true)

    # Make an API request to your API provider
    # This might be useful: http://www.rubyinside.com/nethttp-cheat-sheet-2940.html

    # Parse the response to your API request, and raise any errors using the DiscourseChat::ProviderError
    error_key = 'chat_integration.provider.hipchat.invalid_color'
    raise ::DiscourseChat::ProviderError.new info: {error_key: error_key}

  end
end
```

### Translation keys
In `client.en.yml`, you should specify a title for your provider, titles & help information for any parameters, and any error keys that you're using when raising a `DiscourseChat::ProviderError`. For example:


```yml
en:
  js:
    chat_integration:
      provider:
        hipchat:
          title: "HipChat"
          param:
            name:
              title: "Name"
              help: "A name to describe the channel. It is not used for the connection to HipChat."
            webhook_url:
              title: "Webhook URL"
              help: "The webhook URL created in your HipChat integration"
            color:
              title: "Color"
              help: "The colour of the message in HipChat. Must be one of yellow,green,red,purple,gray,random"
          errors:
            invalid_color: "The API rejected the color you selected"
```

You should make sure to also provide translations for any site settings you have created. There is no need to define any server-side translations, unless you're using them in your `self.trigger_notification` implementation

## Adding Slash Command Support :speech_balloon:
So, you've got notifications working but you want to be able to control the rules from inside your chat system. The common way to do that is using "slash commands". Different chat systems implement them slightly differently, but the general idea is that you have keywords for "actions", and can then supply parameters afterwards. For example, in Slack we have
```text
/discourse watch support tag:help
```
In order to do this you need to find out what method your chat system provides for communicating using Slash commands. Most providers have the ability to "register" a slash command, and then enter a URL which will receive a POST request whenever your slash command is invoked. 

discourse-chat-integration provides a few systems to help you with this. To register a new URL on the forum under `/chat-integration/`, you should create a new file in your provider's folder with a name like `telegram_command_controller.rb`.

```
module DiscourseChat::Provider::TelegramProvider
  class TelegramCommandController < DiscourseChat::Provider::HookController
    requires_provider ::DiscourseChat::Provider::TelegramProvider::PROVIDER_NAME

    before_filter :telegram_token_valid?, only: :command

    skip_before_filter :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :command

    def command
      # Work out which channel the commands are coming from
      chat_id = params['message']['chat']['id']

      provider = DiscourseChat::Provider::TelegramProvider::PROVIDER_NAME

      channel = DiscourseChat::Channel.with_provider(provider).with_data_value('chat_id', chat_id).first

      if channel.exists?

        # This is something like "watch support tag:hello"
        text = params['message']['text']

        # Split each parameter into its own item
        tokens = message['text'].split(" ")
      
        # Use the helper method to process the command
        response = ::DiscourseChat::Helper.process_command(channel, tokens)

        # You can call methods from your provider module to send
        # a response back
        DiscourseChat::Provider::TelegramProvider.sendMessage(message)
     end

      # Always give telegram a success message, otherwise we'll stop receiving webhooks
      data = {
        success: true
      }
      render json: data
    end

    def telegram_token_valid?
      params.require(:token)

      if SiteSetting.chat_integration_telegram_secret.blank? ||
         SiteSetting.chat_integration_telegram_secret != params[:token]
        raise Discourse::InvalidAccess.new
      end
    end
  end

  class TelegramEngine < ::Rails::Engine
    engine_name DiscourseChat::PLUGIN_NAME + "-telegram"
    isolate_namespace DiscourseChat::Provider::TelegramProvider
  end

  TelegramEngine.routes.draw do
    post "command/:token" => "telegram_command#command"
  end
end
```

Some notable things:
- Your controller should inherit from `DiscourseChat::Provider::HookController`. This makes sure it is disabled when the plugin is disabled
- You need to verify the authenticity of the request somehow. This will vary per-provider, but a `before_filter` normally works well.
- The `skip_before_filter` items are required for your endpoint to work when called by your provider. 
- You should define a `Rails::Engine` inside your provider's module. It should end with `Engine`, and will be automatically loaded under the URL `/chat-integration/<provider name>`
- There is a helper method `DiscourseChat::Helper.process_command(channel, tokens)` which deals with the actual logic of creating/editing rules. You simply pass it the channel object and an array of strings

**Language Strings**
To use the `Helper.process_command` method, you need to define these language strings for your provider in `server.en.yml`:

```
      mattermost:
        status:
          header: |
            *Rules for this channel*
            (if multiple rules match a post, the topmost rule is executed)
          no_rules: "There are no rules set up for this channel. Run `/discourse help` for instructions."
          rule_string: "*%{index})* *%{filter}* posts in *%{category}*"
          rule_string_tags_suffix: " with tags: *%{tags}*"
        parse_error: "Sorry, I didn't understand that. Run `/discourse help` for instructions."
        create:
          created: "Rule created successfully"
          updated: "Rule updated successfully"
          error: "Sorry, an error occured while creating that rule."
        delete:
          success: "Rule deleted successfully"
          error: "Sorry, an error occured while deleting that rule. Run `/discourse status` for a list of rules."
        not_found:
          tag: "The *%{name}* tag cannot be found."
          category: "The *%{name}* category cannot be found. Available categories: *%{list}*"
        help: |
          *New rule:* `/discourse [watch|follow|mute] [category] [tag:name]`
          (you must specify a rule type and at least one category or tag)
          - *watch* – notify this channel for new topics and new replies
          - *follow* – notify this channel for new topics
          - *mute* – block notifications to this channel

          *Remove rule:* `/discourse remove [rule number]`
          (`[rule number]` can be found by running `/discourse status`)

          *List rules:* `/discourse status`
          
          *Help:* `/discourse help`
```

## Adding Transcript Posting Support :scroll: 

Posting transcripts is the hardest part of implementing a provider for discourse-chat-integration. Very little logic is available for sharing between providers, because of huge differences in provider APIs.

As more providers are implemented, it may be possible to abstract behaviour so that it can be shared. PRs for such abstraction would be welcome alongside transcript support for more providers.

There is one helper method, which handles storing the transcript on the server ready for the user to write a draft. The `DiscourseChat::Helper.save_transcript(text)` method takes a string (containing the body of a post), and returns a secret string. The transcript will be stored on the server for 1 hour. 

https://github.com/discourse/discourse-chat-integration/blob/4f9ad4efefa0270e00a24e711dd65ff1928b82cf/app/helpers/helper.rb#L192-L198

To let the user access the transcript, you should give them a link in the format 
```
link = "#{Discourse.base_url}/chat-transcript/#{secret}"
```

The best way to go about implementing transcript support for a new provider is to look at the Slack implementation:

https://github.com/discourse/discourse-chat-integration/blob/master/lib/discourse_chat/provider/slack/slack_transcript.rb
