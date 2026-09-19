# ADR 1: Custom Methods Format Change

## Context

We would like these definitions to be usable by any language. The original `holidays` project was written purely in `ruby` but the definitions were generally plain `YAML`.

The issue is that `ruby` has been sprinkled into the otherwise plain `YAML` when it made sense with no plan for use outside of `ruby`. This makes sense when you are never planning on using the `YAML` files in other languages.

Over time we have [been working](https://github.com/holidays/definitions/issues/7) to make the syntax more generic so that other language implementations could consume them. The last hurdle was custom methods.

An example of the original format:

```yaml
methods:
  ca_victoria_day:
    arguments: year
    source: |
      date = Date.civil(year, 5, 24)
      if date.wday > 1
        date -= (date.wday - 1)
      elsif date.wday == 0
        date -= 6
      end

      date
```

As you can see the actual function is just plain `ruby`.

After lots of trial and error I have decided that I cannot see a generic format for this logic that would satisfy all use cases for existing custom methods in our definitions. While some custom methods are relatively simple `if/else` statements there are many that are much more complicated.

An example of a 'complicated' custom method from the `ch` (Swiss) region:

```yaml
  ch_vd_lundi_du_jeune_federal:
    # Monday after the third Sunday of September
    arguments: year
    ruby: |
      date = Date.civil(year,9,1)
      # Find the first Sunday of September
      until date.wday.eql? 0 do
        date += 1
      end
      # There are 15 days between the first Sunday
      # and the Monday after the third Sunday
      date + 15
```

The logic itself is not hard to follow but coming up with a generic way to phrase this seems like a complex problem. Every attempt that was made devolved into very complex parsers of nested `YAML` so that we correctly handled each new edge case that appeared. It was very slow going and the complexity was growing and growing.

Additionally, having a complex `YAML` syntax for custom methods would require each downstream repository to implement the 'standard'. That seems pretty scary to think about maintaining.

The other option is to just make each future language provide their own implementations.

## Decision

The decision is to simply require language-specific implementations of custom methods. Since all custom methods are currently in `ruby` we are changing every `source` field to `ruby`. In the future new languages will need to provide their own implementations. For example, we could add a `golang` or `swift` section next to the existing `ruby` section.

There are three significant advantages:

 - It is very easy to understand
 - All holidays using custom methods have tests so each downstream project will have built-in protection in case a bug is introduced in only one language implementation
 - It is very easy to implement for the current `ruby` implementation (which is our only project currently)

There are significant downsides:

 - Possible divergence between languages due to separate implementations, causing confusion and frustration
 - More pressure on maintainers to handle the various implementations, ensuring they can build without issues when new custom methods are added
 - Confusion for new contributors who may only be comfortable in a single language
 - New downstream languages will have a higher hurdle to overcome since they will need to implement the existing logic in their own language

In the end I don't want to hold things up because of _possible_ new language implementations that might show up in the future. I personally want to create a new `golang` version of `holidays` but beyond that maybe no one else will consume these definitions!

If the `holidays` projects become wildly popular in the future and this becomes a huge problem then I can address it with the (presumably huge) community to find a solution.

## Consequences

We might lose contributions due to confusion or fear.

We might burn out maintainers if the juggling of languages becomes too much of a burden.

This puts more pressure for the completion of an updated [test framework](https://github.com/holidays/definitions/issues/42) for downstream repositories.

## Status

Accepted.
