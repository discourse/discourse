### Services

There are many different types of services which need to do many different
things. We have a lot of them already in chat, a selection:

* [ChatChannelArchiveService](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_channel_archive_service.rb)
* [ChatTranscriptService](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_transcript_service.rb)
* [ChatMessageCreator](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_message_creator.rb)
* [ChatMessageUpdater](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_message_updater.rb)
* [ChatMessageDestroyer](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/app/services/chat_message_destroyer.rb)
* [ChatMessagePublisher](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/app/services/chat_publisher.rb)
* [MessageMover](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/message_mover.rb)
* [SlackCompatibility](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/slack_compatibility.rb)
* [ChatChannelFetcher](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_channel_fetcher.rb)
* [ChatMessageReactor](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_message_reactor.rb)
* [ChatChannelMembershipManager](https://github.com/discourse/discourse/blob/f34b4f67b1f15c51ecba9ad73b4e39515cf9e988/plugins/chat/lib/chat_channel_membership_manager.rb)

These services all do different things. Some are purely for data fetching (e.g.
ChatChannelFetcher), others are used for MessageBus publishing (e.g.
ChatMessagePublisher), while still more handle complicated processes that
include doing things like this (taking ChatMessageCreator as an example):

* Validating input parameters
* Raising errors based on failed validation, access control, and other issues
* Querying the database
* Validating current database record state
* Changing database record state
* Triggering DiscourseEvent events
* Calling other services
* Enqueueing jobs
* Checking permissions with Guardian
* Logging, both to STDOUT and to things like StaffActionLogger
* Interacting with MessageBus

When writing services, we also need to think about how we handle failure and
success states, especially for the Controllers that are most often calling them
(though of course services can and do call other services). With that in mind we
need to handle each different function of services differently to make it easier
for the developer.

#### Errors

We are doing this a few different ways right now, here are some examples:

* Raising errors, either custom ones or things like `Discourse::InvalidParameters`
  as a form of control flow
* Calling Guardian `ensure_X!` variants which raise an error if the condition is
  not met
* Returning a true/false value and message based on the result
* Catching raised errors within the service and expecting the caller to check
  for them

Most errors need to be shown to the user as well (though not all). I think we
already have a better solution for this -- the `HasErrors` module,
which behaves similarly to ActiveModel::Errors. Using this, we can:

* Add arbitrary error messages
* Add all errors from ActiveRecord models when calling their own .validate
  Methods

Sometimes we need to stop the world when we find one of these errors, other
times we can just collect them and show them all at the end. The base class for
service objects should support both. We can define many ease-of-use methods in
the `ServiceBase` class to make it much easier to raise and log errors for
failure states. This leads into the next section.

#### Success and Failure

For most services (excluding pure data fetching ones like ChatChannelFetcher) we
want to know a result of the service call and any errors that may have been
encountered that we can show to the user. For this purpose we should have a
class, called ServiceResult, that encapsulates this. The base service class can
orchestrate these results, but the gist of it is:

* It has a status indicating whether the service succeeded or failed
* It has the capacity to store multiple `errors`
* It has the capacity to store a success `message`
* It has the capacity to store arbitrary data for successful service calls, e.g.
  an ActiveRecord model that was created as part of the service call

Then the caller can simply inspect the result of the service method call:

```ruby
result = ChatChannelArchiveService.create_archive_process(params...)
if result.failed?
  render json: failed_json.merge(errors: result.errors), status: result.status
end
```

The `result.status` can be derived from the `error_type` defined when adding
errors above. The most common HTTP status code would be 400, but 403 and 404 are
relatively common as well. For a success case which serializes the result, it
would look something more like this:

```ruby
result = ChatChannelArchiveService.create_archive_process(params...)
if result.succeeded?
  render_serialized(ChatChannelArchiveSerializer, result.service_data.chat_channel_archive)
end
```

#### Guardian

There are always permissions checks that we will need to do within service
objects. Sometimes the controller checks some of these in a `before` action and
other times its up to the service. There is a kind of tension and duplication of
work effort here, since we may end up checking permissions on something (a
chat channel for example) multiple times.

I don't think there is an easy solution to this, that doesn't involve some
contortions around caching Guardian call signatures and their results for a
specific user inside some sort of wrapper object. For now I think we can leave
this, unless it's really causing a lot of performance woes.

#### Enqueueing Jobs

This can be done via the base class's `enqueue_job` and `enqueue_job_at` methods,
rather than calling Jobs.enqueue directly.

#### Logging

As mentioned above, there are two types of logging:

* STDOUT logging using Rails.logger and Discourse.warn_exception
* UserHistory and StaffActionLogger database-level logs

Both of these can be handled via the base class' `log_message`, `log_user_history`,
and `log_staff_action` methods.

#### MessageBus

Ideally, any MessageBus interactions should be done via a dedicated MessageBus
service, such as ChatMessagePublisher.

#### Data Payloads / Params

Sometimes (e.g. for things like ChatMessageCreator) we require a lot of params
for the service to work correctly. Instead of passing these through the
initialize block, we should instead make a XPayload class within the service
class and define with `attr_accessor` the params needed for the service. This
can easily be done with `Class.new.tap { |x| x.param = y }` in the controller.

Later, we may also want these payload classes to define their own validations of
required parameters etc. if necessary, if we have a standard `.validate` method
on all of them then we can pass results to the service class which can raise
them to the base class.

----

With all this in mind, I have refactored some controller endpoints and existing
service objects to follow these proposed patterns, including new `ServiceBase`
and `ServiceResult` classes to demonstrate what I mean. Please feel free to
comment on any part of this with suggestions or errors in my line of thinking.
