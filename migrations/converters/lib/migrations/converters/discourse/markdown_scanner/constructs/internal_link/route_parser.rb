# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          class InternalLink < Base
            # The route grammar: reads a path (with its query and fragment) into
            # the target fields of the record it names. A pure function of the
            # path string — the construct has already decided the URL is
            # internal.
            class RouteParser
              # A `/u/<name>` segment, read like `Base::WORD_SOURCE` but
              # unanchored.
              WORD = /#{Base::WORD_SOURCE}/
              private_constant :WORD

              # A single path segment, up to the next `/`, `?` or `#`.
              SEGMENT = %r{[^/?#]+}
              private_constant :SEGMENT

              # `/t/<id>` or `/t/<id>/<post_number>`, the id-only forms.
              TOPIC_NUMERIC =
                %r{\A/t/(?<id>#{Base::ID_PATTERN})(?:/(?<post_number>#{Base::ID_PATTERN}))?(?=[/?#]|\z)}
              private_constant :TOPIC_NUMERIC

              # `/t/<slug>/<id>` or `/t/<slug>/<id>/<post_number>`. The slug is
              # `-` for the slugless form.
              TOPIC_SLUG =
                %r{\A/t/#{SEGMENT}/(?<id>#{Base::ID_PATTERN})(?:/(?<post_number>#{Base::ID_PATTERN}))?(?=[/?#]|\z)}
              private_constant :TOPIC_SLUG

              # `/t/<slug>` alone — core routes it to the topic with that slug.
              # One segment only, and never all digits: a short digit run is an
              # id, an overlong one is the id-or-numeric-title ambiguity,
              # refused rather than guessed.
              TOPIC_SLUG_ONLY = %r{\A/t/(?<slug>(?!\d+(?=[/?#]|\z))#{SEGMENT})(?=[?#]|\z)}
              private_constant :TOPIC_SLUG_ONLY

              POST = %r{\A/p/(?<id>#{Base::ID_PATTERN})(?=[/?#]|\z)}
              private_constant :POST

              # The boundary keeps `/u/bob!!!` from reading as user `bob` — such
              # a URL is no route on the destination either, so rewriting it
              # would launder an invalid link. A dotted suffix (`/u/bob.json`)
              # folds into the name, since the name grammar allows interior
              # dots.
              USER = %r{\A/u(?:sers)?/(?<name>#{WORD})(?=[/?#]|\z)}
              private_constant :USER

              # The list filters a category's tabs are addressed by (core's
              # `Discourse.filters`).
              CATEGORY_FILTER = "latest|unread|new|unseen|top|read|posted|bookmarks|hot"
              private_constant :CATEGORY_FILTER

              # Where a category's slug path stops. Core routes all of these
              # *inside* `c/*category_slug_path_with_id`, so Rails takes the
              # tail off before the glob resolves and
              # `Category.find_by_slug_path_with_id` never sees it. The longer
              # forms all open with one of these segments.
              CATEGORY_TAIL = %r{/(?:l/(?:#{CATEGORY_FILTER})|none|all|subcategories)(?=[/?#]|\z)}
              private_constant :CATEGORY_TAIL

              # A further slug segment, unless it opens the tail. Guards only
              # the segments after the first, so a category whose own slug is
              # `all` (`/c/all`) still reads as a slug — `none` is the one core
              # reserves.
              CATEGORY_SLUG_SEGMENT = %r{(?!#{CATEGORY_TAIL})/#{SEGMENT}}
              private_constant :CATEGORY_SLUG_SEGMENT

              # `/c/<slug-path>/<id>`, or `/c/<id>` with no slug. Anchored on
              # the id, so a category's filter tail (`/l/latest`) stays in the
              # suffix instead of reading as more slug. The slug path is lazy,
              # so the id is the first numeric segment ending a path component:
              # greedy, `/c/support/6/l/latest` would fold the tail into the
              # slug, and `/c/2015/6` would read slug `2015` rather than id 6.
              # Being unable to run past the tail also keeps an intersection
              # URL's tag id out of the category.
              CATEGORY_ID =
                %r{\A/(?:c|category)/(?:(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*?)/)?(?<id>#{Base::ID_PATTERN})(?=[/?#]|\z)}
              private_constant :CATEGORY_ID

              # The legacy id-less form, whose segments join with `:` into a
              # slug path. Only reached when no segment parses as an id —
              # including an overlong digit run, which is a numeric slug. Stops
              # at the filter tail like the id form, so `/c/support/l/latest`
              # names `support` and not a `support:l:latest` that resolves to
              # nothing.
              CATEGORY_SLUG =
                %r{\A/(?:c|category)/(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*)(?=[/?#]|\z)}
              private_constant :CATEGORY_SLUG

              # `/tag/<name>` / `/tags/<name>`. The guard routes the two
              # reserved multi-tag forms to their own grammars below:
              # `/tags/c/…` and `/tags/intersection/…` name several records, not
              # a tag called `c` or `intersection`. It needs the trailing `/`,
              # because a bare `/tags/intersection` IS the page of a tag with
              # that name.
              TAG = %r{\A/tags?/(?!(?:c|intersection)/)(?<name>#{SEGMENT})}
              private_constant :TAG

              # Where a category+tag route may continue after the tag name.
              # Anything else — most importantly a trailing numeric segment,
              # which core's canonical route order would read as a tag id —
              # leaves the route unparsed, so the ambiguity refuses instead of
              # picking a reading.
              TAG_ROUTE_END = %r{(?=/l/(?:#{CATEGORY_FILTER})(?=[/?#]|\z)|[?#]|\z)}
              private_constant :TAG_ROUTE_END

              # The tag segment of a category+tag route. All-numeric is the
              # tag-id ambiguity above, and `none`/`all` are core's reserved
              # subcategory filters.
              TAG_NAME_SEGMENT = %r{(?!(?:\d+|none|all)(?=[/?#]|\z))#{SEGMENT}}
              private_constant :TAG_NAME_SEGMENT

              # `/tags/c/<category-path>/<id>/<tag>` — topics carrying a tag
              # within a category, the category read exactly like CATEGORY_ID.
              # An optional `none`/`all` between them is core's subcategory
              # filter, kept in the tag path so the rebuilt route filters the
              # same way.
              TAG_CATEGORY_ID =
                %r{\A/tags/c/(?:(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*?)/)?(?<id>#{Base::ID_PATTERN})/(?:(?<filter>none|all)/)?(?<tag>#{TAG_NAME_SEGMENT})#{TAG_ROUTE_END}}
              private_constant :TAG_CATEGORY_ID

              # The legacy id-less form, joining segments into a slug path like
              # CATEGORY_SLUG. The path is lazy so the last eligible segment is
              # the tag.
              TAG_CATEGORY_SLUG =
                %r{\A/tags/c/(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*?)/(?:(?<filter>none|all)/)?(?<tag>#{TAG_NAME_SEGMENT})#{TAG_ROUTE_END}}
              private_constant :TAG_CATEGORY_SLUG

              # `/tags/intersection/<t1>/<t2>[/…]` — topics carrying every
              # listed tag. Two names minimum: core routes a single-segment form
              # as that one tag's page, which the TAG route already reads.
              TAG_INTERSECTION =
                %r{\A/tags/intersection/(?<tags>#{SEGMENT}(?:/#{SEGMENT})+)(?=[?#]|\z)}
              private_constant :TAG_INTERSECTION

              GROUP = %r{\A/(?:g|groups?)/(?<name>#{SEGMENT})}
              private_constant :GROUP

              # A path that steps INTO a coordinate-bearing route family — the
              # family segment followed by `/`. A bare family segment (`/u`,
              # `/badges`) is that family's coordinate-free index page.
              COORDINATE_OPENER = %r{\A/(?:t|p|u|users|c|category|g|groups?|tags?|badges)/}
              private_constant :COORDINATE_OPENER

              # `/badges/<id>` or `/badges/<id>/<slug>`; the slug is regenerated
              # at import, so the route consumes it rather than keeping it as
              # suffix.
              BADGE = %r{\A/badges/(?<id>#{Base::ID_PATTERN})(?:/#{SEGMENT})?(?=[/?#]|\z)}
              private_constant :BADGE

              class << self
                # Returns the target fields plus `route_length` (how much of
                # `rest` the route consumed; the remainder is the suffix), or
                # nil for an unknown path.
                def parse(rest)
                  topic_or_post(rest) || post_by_id(rest) || user(rest) || category(rest) ||
                    tag_category(rest) || tag_intersection(rest) || tag(rest) || group(rest) ||
                    badge(rest)
                end

                # Whether an UNPARSED path still opened a coordinate-bearing
                # route family (`/t//209` with its empty slug, `/u/bob!!!`, the
                # reserved `/tags/c/…` forms). Such a tail plausibly carries the
                # OLD site's ids, so rewriting just the origin under it would
                # point the new host at stale coordinates. Callers use this to
                # keep those paths out of the origin-only `:site` rewrite and
                # report them instead.
                def coordinate_shaped?(path)
                  COORDINATE_OPENER.match?(path)
                end

                private

                def topic_or_post(rest)
                  match = TOPIC_NUMERIC.match(rest) || TOPIC_SLUG.match(rest)
                  if match.nil?
                    match = TOPIC_SLUG_ONLY.match(rest)
                    # By name, like a user route: resolution looks the slug up
                    # and restores the source on no unique match.
                    return match && target(match, :topic, target_name: match[:slug])
                  end

                  if match[:post_number]
                    target(
                      match,
                      :post,
                      target_topic_id: match[:id].to_i,
                      target_post_number: match[:post_number].to_i,
                    )
                  else
                    target(match, :topic, target_id: match[:id].to_i)
                  end
                end

                def post_by_id(rest)
                  match = POST.match(rest)
                  match && target(match, :post, target_id: match[:id].to_i)
                end

                def user(rest)
                  match = USER.match(rest)
                  match && target(match, :user, target_name: match[:name])
                end

                def category(rest)
                  if (match = CATEGORY_ID.match(rest))
                    target(match, :category, target_id: match[:id].to_i)
                  elsif (match = CATEGORY_SLUG.match(rest))
                    target(match, :category, target_name: match[:path].tr("/", ":"))
                  end
                end

                def tag(rest)
                  match = TAG.match(rest)
                  match && target(match, :tag, target_name: match[:name])
                end

                # The tag path keeps the optional `none`/`all` filter in front
                # of the tag name, so rebuilding preserves the filter without a
                # column of its own.
                def tag_category(rest)
                  match = TAG_CATEGORY_ID.match(rest) || TAG_CATEGORY_SLUG.match(rest)
                  return nil unless match

                  tag_path = [match[:filter], match[:tag]].compact.join("/")
                  if match.names.include?("id") && match[:id]
                    target(
                      match,
                      :category_tag,
                      target_id: match[:id].to_i,
                      target_tag_path: tag_path,
                    )
                  else
                    target(
                      match,
                      :category_tag,
                      target_name: match[:path].tr("/", ":"),
                      target_tag_path: tag_path,
                    )
                  end
                end

                def tag_intersection(rest)
                  match = TAG_INTERSECTION.match(rest)
                  match && target(match, :tag_intersection, target_tag_path: match[:tags])
                end

                def group(rest)
                  match = GROUP.match(rest)
                  match && target(match, :group, target_name: match[:name])
                end

                def badge(rest)
                  match = BADGE.match(rest)
                  match && target(match, :badge, target_id: match[:id].to_i)
                end

                def target(
                  match,
                  target_type,
                  target_id: nil,
                  target_name: nil,
                  target_topic_id: nil,
                  target_post_number: nil,
                  target_tag_path: nil
                )
                  {
                    target_type:,
                    target_id:,
                    target_name:,
                    target_topic_id:,
                    target_post_number:,
                    target_tag_path:,
                    route_length: match[0].length,
                  }
                end
              end
            end
          end
        end
      end
    end
  end
end
