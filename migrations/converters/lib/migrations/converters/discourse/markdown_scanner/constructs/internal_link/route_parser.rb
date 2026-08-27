# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      module MarkdownScanner
        module Constructs
          class InternalLink < Base
            # The route grammar: reads a path (with its query and fragment) into
            # the target fields of the record it names. A pure function of the
            # path string — the construct has already decided the URL is internal
            # (host, prefix, boundary) before asking what it points at.
            class RouteParser
              # A `/u/<name>` segment, read like a username (see
              # `Base::WORD_SOURCE`) but unanchored.
              WORD = /#{Base::WORD_SOURCE}/
              private_constant :WORD

              # A single path segment, up to the next `/`, query `?` or fragment `#`.
              SEGMENT = %r{[^/?#]+}
              private_constant :SEGMENT

              # `/t/<id>` (topic) or `/t/<id>/<post_number>` (post by coordinates), the
              # id-only forms where the first `/t/` component is all digits. The id
              # bound (see `Base::ID_PATTERN`) keeps a 19+-digit numeric title literal:
              # its trailing lookahead makes an overlong run backtrack to no match.
              TOPIC_NUMERIC =
                %r{\A/t/(?<id>#{Base::ID_PATTERN})(?:/(?<post_number>#{Base::ID_PATTERN}))?(?=[/?#]|\z)}
              private_constant :TOPIC_NUMERIC

              # `/t/<slug>/<id>` (topic) or `/t/<slug>/<id>/<post_number>` (post by
              # coordinates). The slug is `-` for the slugless `/t/-/<id>` form.
              TOPIC_SLUG =
                %r{\A/t/#{SEGMENT}/(?<id>#{Base::ID_PATTERN})(?:/(?<post_number>#{Base::ID_PATTERN}))?(?=[/?#]|\z)}
              private_constant :TOPIC_SLUG

              # `/t/<slug>` alone — core routes it to the topic with that slug.
              # A single segment only: a second segment that isn't an id is no
              # route, and the id forms above are tried first. All-digit
              # segments stay out — a short run is an id, an overlong run is
              # the id-or-numeric-title ambiguity, refused rather than guessed.
              TOPIC_SLUG_ONLY = %r{\A/t/(?<slug>(?!\d+(?=[/?#]|\z))#{SEGMENT})(?=[?#]|\z)}
              private_constant :TOPIC_SLUG_ONLY

              POST = %r{\A/p/(?<id>#{Base::ID_PATTERN})(?=[/?#]|\z)}
              private_constant :POST

              # The boundary keeps a username-prefixed junk segment (`/u/bob!!!`)
              # from reading as user `bob` — such a URL is not a route on the
              # destination either, so rewriting it would launder an invalid
              # link. A dotted suffix (`/u/bob.json`) folds into the name, since
              # the name grammar allows interior dots; resolution then decides,
              # and an unresolved link restores its verbatim source.
              USER = %r{\A/u(?:sers)?/(?<name>#{WORD})(?=[/?#]|\z)}
              private_constant :USER

              # The list filters a category's tabs are addressed by (core's
              # `Discourse.filters`).
              CATEGORY_FILTER = "latest|unread|new|unseen|top|read|posted|bookmarks|hot"
              private_constant :CATEGORY_FILTER

              # Where a category's slug path stops. Core routes all of these *inside*
              # `c/*category_slug_path_with_id`, so Rails takes the tail off before the
              # glob is resolved and `Category.find_by_slug_path_with_id` never sees it —
              # the tail is not slug. `/l/top/<period>` and the tag-intersection forms
              # below `/none` and `/all` open with one of these segments, so matching the
              # opening one is enough; the rest stays in the suffix either way.
              CATEGORY_TAIL = %r{/(?:l/(?:#{CATEGORY_FILTER})|none|all|subcategories)(?=[/?#]|\z)}
              private_constant :CATEGORY_TAIL

              # A further slug segment, unless it opens the tail. Only guards the segments
              # after the first, so a category whose own slug is `all` (`/c/all`) still
              # reads as a slug — `none` is the one core reserves.
              CATEGORY_SLUG_SEGMENT = %r{(?!#{CATEGORY_TAIL})/#{SEGMENT}}
              private_constant :CATEGORY_SLUG_SEGMENT

              # `/c/<slug-path>/<id>`, or `/c/<id>` with no slug. Anchored on the id the
              # way the topic routes are, so the route ends there and a category's
              # filter tail (`/l/latest`, the ordinary URL of a category's Latest tab)
              # stays in the suffix instead of being read as more slug.
              #
              # The slug path is lazy so the id is the first numeric segment that ends a
              # path component: greedy, `/c/support/6/l/latest` would fold the tail into
              # the slug and resolve nothing. With no tail the lazy path still stops on
              # the last segment, so `/c/2015/6` reads id 6, not slug `2015`. It also
              # can't run past the tail, which keeps the tag id of an intersection URL
              # (`/c/support/none/<tag>/<tag-id>`) from being read as the category's.
              CATEGORY_ID =
                %r{\A/c/(?:(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*?)/)?(?<id>#{Base::ID_PATTERN})(?=[/?#]|\z)}
              private_constant :CATEGORY_ID

              # The legacy id-less form, `/c/<slug>` or `/c/<parent>/<child>`, whose
              # segments join with `:` into a slug path. Only reached when no segment
              # parses as an id — including an overlong digit run, which is a numeric
              # slug rather than an id (see `Base::ID_PATTERN`). Stops at the filter tail
              # like the id form, so `/c/support/l/latest` names `support` instead of a
              # `support:l:latest` that resolves to nothing.
              CATEGORY_SLUG = %r{\A/c/(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*)(?=[/?#]|\z)}
              private_constant :CATEGORY_SLUG

              # `/tag/<name>` / `/tags/<name>`. The guard routes the two reserved
              # multi-tag forms to their own grammars below: `/tags/c/…` and
              # `/tags/intersection/…` name several records, not a tag called `c`
              # or `intersection`. The guard needs the trailing `/` because a bare
              # `/tags/intersection` IS the page of a tag with that name.
              TAG = %r{\A/tags?/(?!(?:c|intersection)/)(?<name>#{SEGMENT})}
              private_constant :TAG

              # Where a category+tag route may continue after the tag name: a list
              # filter tab, the query/fragment, or the end. Anything else after the
              # tag — most importantly a trailing numeric segment, which core's
              # canonical route order would read as a tag id rather than more path —
              # leaves the route unparsed, so the ambiguity refuses instead of
              # silently picking a reading.
              TAG_ROUTE_END = %r{(?=/l/(?:#{CATEGORY_FILTER})(?=[/?#]|\z)|[?#]|\z)}
              private_constant :TAG_ROUTE_END

              # The tag segment of a category+tag route. All-numeric is the
              # canonical-route tag-id ambiguity described above, and `none`/`all`
              # are the subcategory filters core reserves — neither can be a tag
              # name here.
              TAG_NAME_SEGMENT = %r{(?!(?:\d+|none|all)(?=[/?#]|\z))#{SEGMENT}}
              private_constant :TAG_NAME_SEGMENT

              # `/tags/c/<category-path>/<id>/<tag>` — topics carrying a tag within a
              # category, the category part read exactly like CATEGORY_ID (lazy slug
              # path, first id-shaped segment ends it). An optional `none`/`all`
              # between category and tag is core's subcategory filter, kept as part
              # of the tag path so the rebuilt route filters the same way.
              TAG_CATEGORY_ID =
                %r{\A/tags/c/(?:(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*?)/)?(?<id>#{Base::ID_PATTERN})/(?:(?<filter>none|all)/)?(?<tag>#{TAG_NAME_SEGMENT})#{TAG_ROUTE_END}}
              private_constant :TAG_CATEGORY_ID

              # The legacy id-less form, `/tags/c/<slug-path>/<tag>`, segments
              # joining into a slug path like CATEGORY_SLUG. The path is lazy so the
              # last eligible segment is the tag, not more slug.
              TAG_CATEGORY_SLUG =
                %r{\A/tags/c/(?<path>#{SEGMENT}#{CATEGORY_SLUG_SEGMENT}*?)/(?:(?<filter>none|all)/)?(?<tag>#{TAG_NAME_SEGMENT})#{TAG_ROUTE_END}}
              private_constant :TAG_CATEGORY_SLUG

              # `/tags/intersection/<t1>/<t2>[/<t3>…]` — topics carrying every listed
              # tag. Two names minimum: core routes a single-segment form as the page
              # of that one tag, which the TAG route already reads.
              TAG_INTERSECTION =
                %r{\A/tags/intersection/(?<tags>#{SEGMENT}(?:/#{SEGMENT})+)(?=[?#]|\z)}
              private_constant :TAG_INTERSECTION

              GROUP = %r{\A/g/(?<name>#{SEGMENT})}
              private_constant :GROUP

              # A path that steps INTO a coordinate-bearing route family — the
              # family segment followed by `/`, so there was an attempt at
              # coordinates after it. A bare family segment (`/u`, `/badges`,
              # `/tags`) is that family's index page: coordinate-free, and not
              # matched here.
              COORDINATE_OPENER = %r{\A/(?:t|p|u|users|c|g|tags?|badges)/}
              private_constant :COORDINATE_OPENER

              # `/badges/<id>` or `/badges/<id>/<slug>`; the slug is regenerated at
              # import, so it's consumed by the route rather than kept as suffix.
              BADGE = %r{\A/badges/(?<id>#{Base::ID_PATTERN})(?:/#{SEGMENT})?(?=[/?#]|\z)}
              private_constant :BADGE

              class << self
                # Matches `rest` (the path onwards) against the known routes in turn.
                # Returns the target fields plus `route_length` (how much of `rest` the
                # route consumed; the remainder is the suffix), or nil for an unknown
                # path.
                def parse(rest)
                  topic_or_post(rest) || post_by_id(rest) || user(rest) || category(rest) ||
                    tag_category(rest) || tag_intersection(rest) || tag(rest) || group(rest) ||
                    badge(rest)
                end

                # Whether an UNPARSED path still opened a coordinate-bearing
                # route family (`/t//209` with its empty slug, `/u/bob!!!`, the
                # reserved multi-tag `/tags/c/…` forms). Such a tail plausibly
                # carries the OLD site's ids and slugs, so rewriting just the
                # origin under it would point the new host at stale coordinates
                # — worse than leaving the link verbatim. Callers use this to
                # keep those paths out of the origin-only `:site` rewrite.
                def coordinate_shaped?(path)
                  COORDINATE_OPENER.match?(path)
                end

                private

                def topic_or_post(rest)
                  match = TOPIC_NUMERIC.match(rest) || TOPIC_SLUG.match(rest)
                  if match.nil?
                    match = TOPIC_SLUG_ONLY.match(rest)
                    # By name, like a user route: resolution looks the slug up
                    # and restores the source on no (or no unique) match.
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

                # The category is addressed the way the plain category routes
                # address it (id when present, else the joined slug path); the tag
                # path keeps the optional `none`/`all` filter in front of the tag
                # name, so rebuilding preserves the filter without a column of its
                # own.
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
