# Poll plugin

Allows you to add a poll to the first post of a topic.

# Usage

1. Make your topic title start with "Poll: "
2. Include a list in your post (the **first list** will be used)

## Closing the poll

Change the start of the topic title from "Poll: " to "Closed Poll: ". This feature is disabled if the `allow_user_locale` site setting is enabled.

_Note: closing a topic will also close the poll._

## Specifying the list to be used for the poll

If you have multiple lists in your post and the first list is _not_
the one you want to use for the poll, you can identify the 
list to be used like this:

```
Intro Text

- Item one
- Item two

Here are your choices:

[poll]
- Option 1
- Option 2
[/poll]
```
