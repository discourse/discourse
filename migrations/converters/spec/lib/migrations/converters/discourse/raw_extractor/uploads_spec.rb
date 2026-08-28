# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "external-host marking" do
    let(:internal_link_hosts) { { source_host => nil } }
    let(:sha1) { "a" * 40 }

    # The importer maps a foreign-host row's sha1 only against an explicit
    # allowlist — a colliding basename must not rewrite another site's file —
    # so the extractor has to say which rows are foreign.
    it "marks foreign hosts and leaves the source's own and relative URLs unmarked" do
      extract(
        "![a](https://forum.example.com/uploads/default/original/2X/a/ab/#{sha1}.png) " \
          "![b](https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png) " \
          "![c](/uploads/default/original/2X/a/ab/#{sha1}.png)",
      )

      expect(buffer.uploads.map { |row| row[:external_host] }).to eq([nil, "cdn.example.com", nil])
    end

    context "with a subdirectory install" do
      let(:internal_link_hosts) { { source_host => "/forum" } }
      let(:internal_link_base_prefix) { "/forum" }

      # On a subdirectory install the host alone does not make an upload the
      # source's own: `/other/uploads/…` on the same host belongs to a
      # different application, and mapping its sha1 could rewrite that
      # application's file on a hash collision.
      it "marks an absolute sibling-application upload as external" do
        extract(
          "![in](https://forum.example.com/forum/uploads/default/original/2X/a/ab/#{sha1}.png) " \
            "![out](https://forum.example.com/other/uploads/default/original/2X/a/ab/#{sha1}.png)",
        )

        expect(buffer.uploads.map { |row| row[:external_host] }).to eq([nil, source_host])
      end

      # A relative sibling path has no host an operator could allowlist, so
      # no row is recorded at all and the source text stays.
      it "leaves a relative sibling-application upload verbatim" do
        raw = "![out](/other/uploads/default/original/2X/a/ab/#{sha1}.png)"

        expect(extract(raw)).to eq(raw)
        expect(buffer.uploads).to be_empty
        expect(extractor.engine_refusals).to be_empty
      end

      it "records a relative upload inside the base prefix" do
        extract("![in](/forum/uploads/default/original/2X/a/ab/#{sha1}.png)")

        expect(buffer.uploads.map { |row| row[:external_host] }).to eq([nil])
      end
    end
  end

  describe "unsupported /uploads/ paths" do
    # A generic `/uploads/` path (WordPress and similar) is not an upload
    # reference: it has neither the `original|optimized/` shape nor the
    # short-URL one. It must not become a candidate, a tracked value, or a
    # refusal.
    it "ignores an external generic uploads path" do
      raw = "see https://blog.example.net/wp-content/uploads/2009/12/image1.jpg here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end
  end

  describe "short-URL uploads" do
    # `/uploads/short-url/<token>` carries the base62-encoded sha1 (core's
    # `Upload#short_path`), so the row can carry the decoded 40-hex sha1 and
    # resolve like a long URL.
    let(:decoded) { "#{"0" * 38}7d" }

    it "defers a short-URL image, decoding the token to the sha1" do
      result = extract("![pic](https://forum.example.com/uploads/short-url/21.jpeg)")

      expect(buffer.uploads.size).to eq(1)
      expect(buffer.uploads.first[:upload_id]).to eq(decoded)
      expect(result).to include(buffer.uploads.first[:placeholder])
    end

    it "defers a bare absolute short URL" do
      result = extract("file at https://forum.example.com/uploads/short-url/21.jpeg here")

      expect(buffer.uploads.first[:upload_id]).to eq(decoded)
      expect(result).to include(buffer.uploads.first[:placeholder])
    end

    it "defers a relative short URL at a link target" do
      result = extract("[file](/uploads/short-url/21.jpeg)")

      expect(buffer.uploads.first[:upload_id]).to eq(decoded)
      expect(result).to eq(buffer.uploads.first[:placeholder])
    end

    it "leaves a token that is too long for a sha1 alone" do
      raw = "see /uploads/short-url/#{"z" * 27}.png here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end
  end

  describe "uploads" do
    it "defers an image upload, recording the sha1" do
      result = extract("before ![alt|690x388](upload://abc123XYZ.png) after")

      expect(buffer.uploads.size).to eq(1)
      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq("abc123XYZ")
      expect(result).to eq("before #{upload[:placeholder]} after")
    end

    it "defers an attachment upload" do
      extract("[report.pdf|attachment](upload://Zm9vYmFy.pdf)")

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
    end

    it "takes the size Discourse writes after an attachment" do
      result = extract("[report.pdf|attachment](upload://Zm9vYmFy.pdf) (1.2 MB)")

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
      expect(result).to eq(buffer.uploads.first[:placeholder])
    end

    # Only the sha1 is recorded, so whatever the match covers is re-rendered from
    # the destination's metadata and the rest is dropped. The size group must not
    # reach past the line end, or a parenthesized line of the author's own text
    # disappears from the post.
    {
      "the next line" => "\n(this may take a while)",
      "a line after a blank one" => "\n\n(a caption)",
    }.each do |label, tail|
      it "leaves #{label} alone after an attachment" do
        result = extract("[report.pdf|attachment](upload://Zm9vYmFy.pdf)#{tail}")

        expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
        expect(result).to eq("#{buffer.uploads.first[:placeholder]}#{tail}")
      end
    end

    it "records the verbatim source as original_markdown for an upload:// reference" do
      extract("![alt](upload://abc123.png)")

      expect(buffer.uploads.first[:original_markdown]).to eq("![alt](upload://abc123.png)")
    end

    # Core's link parse fails at the unmatched outer `[` and renders the
    # attachment from the inner bracket, keeping `[foo` literal — so the match
    # must not start one bracket too early and swallow that text.
    it "matches from the inner bracket when an unmatched `[` precedes an attachment" do
      result = extract("[foo[bar|attachment](upload://Zm9vYmFy.pdf)")

      expect(buffer.uploads.size).to eq(1)
      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
      expect(result).to eq("[foo#{buffer.uploads.first[:placeholder]}")
    end
  end

  # `[image|281x500](upload://…)` — a failed image paste whose `!` was lost.
  # Core renders the label literally, pipe and all, as a plain link carrying
  # `data-orig-href`, so the upload is as real as in any other form.
  describe "link-position labels with pipe metadata" do
    it "defers the upload, replacing the whole construct" do
      result = extract("pasted [image|281x500](upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.jpeg) here")

      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq("2Yjf3WE4KOQ88YUb4fUMubKB9My")
      expect(upload[:original_markdown]).to eq(
        "[image|281x500](upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.jpeg)",
      )
      expect(result).to eq("pasted #{upload[:placeholder]} here")
      expect(extractor.engine_refusals).to be_empty
    end

    it "takes a multi-pipe label and an empty pre-pipe part" do
      extract("[a|b|c](upload://Zm9vYmFy.png) and [|690x388](upload://YmFyYmF6.png)")

      expect(buffer.uploads.map { |row| row[:upload_id] }).to eq(%w[Zm9vYmFy YmFyYmF6])
    end

    # The attachment marker folds case (core's split, see the construct), so an
    # upper-cased one still takes the attachment branch — with its size tail,
    # which the link-label branch has no reason to consume.
    it "reads an upper-cased attachment marker as an attachment, size included" do
      result = extract("[r.pdf|ATTACHMENT](upload://Zm9vYmFy.pdf) (1.2 MB)")

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
      expect(result).to eq(buffer.uploads.first[:placeholder])
    end

    # Core links a pipe-less `[label](upload://…)` the same way, so the upload
    # is recorded. The engine tier confirms the occurrence before the replace,
    # and a resolution miss restores the verbatim label.
    it "defers a pipe-less link" do
      body = "[plain label](upload://Zm9vYmFy.png)"
      result = extract(body)

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
      expect(buffer.uploads.first[:original_markdown]).to eq(body)
      expect(result).to eq(buffer.uploads.first[:placeholder])
      expect(extractor.engine_refusals).to be_empty
    end

    it "defers a label with one level of nested brackets" do
      body = "[Juan [John] Hernandez.pdf|attachment](upload://Zm9vYmFy.pdf)"
      result = extract(body)

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
      expect(buffer.uploads.first[:original_markdown]).to eq(body)
      expect(result).to eq(buffer.uploads.first[:placeholder])
      expect(extractor.engine_refusals).to be_empty
    end
  end

  describe "full-URL uploads" do
    let(:sha1) { "0123456789abcdef0123456789abcdef01234567" }

    it "defers an image referenced by a root-relative upload URL" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("before ![pic](#{url}) after")

      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq(sha1)
      expect(upload[:original_markdown]).to eq("![pic](#{url})")
      expect(result).to eq("before #{upload[:placeholder]} after")
    end

    it "defers a markdown link to an absolute upload URL" do
      url = "https://forum.example.com/uploads/default/original/2X/a/ab/#{sha1}.pdf"
      extract("[report](#{url})")

      expect(buffer.uploads.first).to include(
        upload_id: sha1,
        original_markdown: "[report](#{url})",
      )
    end

    it "defers a bare, whitespace-delimited upload URL" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png"
      result = extract("see #{url} thanks")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: url)
      expect(result).to eq("see #{upload[:placeholder]} thanks")
    end

    it "reads the sha1 from an optimized image variant" do
      url = "/uploads/default/optimized/2X/a/ab/#{sha1}_2_690x388.png"
      extract("![x](#{url})")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "recognizes a secure-uploads URL" do
      url = "/secure-uploads/original/2X/a/ab/#{sha1}.png"
      extract("![x](#{url})")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "recognizes a protocol-relative upload URL" do
      url = "//cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      extract("![x](#{url})")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    # A destination carrying a title is still a link core resolves, so the upload
    # behind it has to be carried over like any other.
    it "recognizes an upload URL in an image with a title" do
      url = "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      extract(%(![x](#{url} "a title")))

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "recognizes an upload URL in a link with a title" do
      url = "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.pdf"
      extract(%([report](#{url} 'a title')))

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "recognizes an upload URL with padding around it" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      extract("![x](  #{url}  )")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    # linkify-it reads the scheme case-insensitively, so core links these too.
    %w[HTTPS Https HTTP].each do |scheme|
      it "recognizes an upload URL with a #{scheme} scheme" do
        url = "#{scheme}://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
        extract("![x](#{url})")

        expect(buffer.uploads.first[:upload_id]).to eq(sha1)
      end

      it "recognizes a bare upload URL with a #{scheme} scheme" do
        url = "#{scheme}://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
        extract("see #{url} here")

        expect(buffer.uploads.first[:upload_id]).to eq(sha1)
      end
    end

    it "keeps a bare URL's trailing sentence punctuation out of the match" do
      url = "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("look at #{url}.")

      expect(buffer.uploads.first[:original_markdown]).to eq(url)
      expect(result).to eq("look at #{buffer.uploads.first[:placeholder]}.")
    end

    it "leaves a relative upload URL bare in prose literal" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      raw = "see #{url} thanks"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "defers a bare absolute upload URL in prose" do
      url = "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("see #{url} thanks")

      expect(buffer.uploads.first).to include(upload_id: sha1, original_markdown: url)
      expect(result).to eq("see #{buffer.uploads.first[:placeholder]} thanks")
    end

    # Core linkifies a bare absolute URL after anything but an ASCII letter, digit
    # or `+` (see `uploads_parity_spec.rb`), so a URL glued right after prose
    # punctuation is a link once cooked — the construct defers it too.
    it "defers a bare upload URL glued to preceding punctuation" do
      url = "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("here,#{url} thanks")

      expect(buffer.uploads.first).to include(upload_id: sha1, original_markdown: url)
      expect(result).to eq("here,#{buffer.uploads.first[:placeholder]} thanks")
    end

    # A URL glued right after an ASCII letter isn't linkified by core, and the
    # `//host` inside it isn't a standalone protocol-relative link either
    # (linkify-it's `//` schema rejects the `://` tail), so it stays literal.
    it "leaves a bare upload URL glued to a preceding word character literal" do
      url = "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      raw = "here#{url}"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "ignores a non-upload URL" do
      raw = "![photo](https://example.com/images/photo.png) and https://example.com/page"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "ignores an uploads URL whose basename is not a 40-hex sha1" do
      raw = "![x](/uploads/default/original/2X/a/ab/deadbeef.png)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract a full-URL upload inside a fenced code block" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      raw = <<~MD
        real ![pic](#{url})

        ```
        code ![pic](#{url}) and bare #{url}
        ```
      MD

      result = extract(raw)

      expect(buffer.uploads.size).to eq(1)
      expect(result).to include("code ![pic](#{url}) and bare #{url}")
    end

    it "defers only the inner image of a linked image, leaving the outer link literal" do
      inner = "https://forum.example.com/uploads/default/original/1X/#{sha1}.png"
      result = extract("[![alt|690x388](#{inner})](https://other.example.com/page)")

      expect(buffer.uploads.size).to eq(1)
      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq(sha1)
      # The inner image alone is deferred; the mangled half-link the greedy `[…]`
      # class used to produce is gone.
      expect(upload[:original_markdown]).to eq("![alt|690x388](#{inner})")
      expect(result).to eq("[#{upload[:placeholder]}](https://other.example.com/page)")
    end

    it "defers only the inner image of an image nested in an image description" do
      inner = "https://forum.example.com/uploads/default/original/1X/#{sha1}.png"
      result = extract("![![inner](#{inner})](https://elsewhere.example.com/x.png)")

      expect(buffer.uploads.size).to eq(1)
      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq(sha1)
      # The inner image alone is deferred; the outer `![` and `](…)` stay literal
      # instead of the greedy alt class swallowing through the inner `)`.
      expect(upload[:original_markdown]).to eq("![inner](#{inner})")
      expect(result).to eq("![#{upload[:placeholder]}](https://elsewhere.example.com/x.png)")
    end

    it "defers only the inner short-form upload of an image nested in an image description" do
      result = extract("![![inner](upload://abc123XYZ.png)](https://elsewhere.example.com/x.png)")

      expect(buffer.uploads.size).to eq(1)
      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq("abc123XYZ")
      expect(result).to eq("![#{upload[:placeholder]}](https://elsewhere.example.com/x.png)")
    end

    it "defers both images of an old lightbox (a thumbnail linking to the full image)" do
      thumb = "/uploads/default/optimized/2X/a/ab/#{sha1}_2_100x75.png"
      full = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("[![thumb](#{thumb})](#{full})")

      expect(buffer.uploads.size).to eq(2)
      expect(buffer.uploads.map { |u| u[:original_markdown] }).to eq(["![thumb](#{thumb})", full])
      thumb_ph, full_ph = buffer.uploads.map { |u| u[:placeholder] }
      expect(result).to eq("[#{thumb_ph}](#{full_ph})")
    end
  end

  describe "upload paths outside the URL path" do
    # The storage shape counts only inside the URL's own path. A redirect
    # whose query or fragment carries an upload path is the author's link to
    # the redirect, not to the file — rewriting it as an upload would swap
    # the link for the file it points at.
    let(:upload_path) { "/uploads/default/original/1X/#{sha1}.png" }

    it "leaves a bare redirect URL with an upload path in its query alone" do
      raw = "go to https://forum.example.com/redirect?to=#{upload_path} now"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end

    it "leaves a markdown link with an upload path in its query alone" do
      raw = "[file](https://cdn.example.com/download?file=#{upload_path})"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end

    it "leaves an image with an upload path in its query alone" do
      raw = "![x](https://cdn.example.com/proxy?src=#{upload_path})"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end

    it "leaves a URL with an upload path in its fragment alone" do
      raw = "see https://forum.example.com/page##{upload_path} here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end
  end

  describe "upload URLs with a query" do
    # A signed CDN URL must be taken whole or not at all: replacing only a
    # prefix would leave the signature dangling after the placeholder.
    it "takes a bare upload URL with a long signed query whole" do
      query =
        "X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=#{"a" * 320}&X-Amz-Signature=#{"b" * 64}"
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png?#{query}"
      result = extract("file #{url} end")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: url)
      expect(result).to eq("file #{upload[:placeholder]} end")
    end

    it "takes an upload URL with a query whole in a markdown link" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png?v=2"
      result = extract("[file](#{url})")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: "[file](#{url})")
      expect(result).to eq(upload[:placeholder])
    end

    it "leaves a URL whose query exceeds the cap alone instead of matching a prefix" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png?x=#{"a" * 1200}"
      raw = "file #{url} end"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end

    # Same rule for a wordless over-cap query: 2,000 percent signs are not a
    # short linkify tail, and a prefix match would cut the URL mid-query.
    it "leaves a bare URL with an over-cap punctuation-only query alone" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png?x=#{"%" * 2000}"
      raw = "file #{url} end"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end

    it "leaves a markdown link with an over-cap punctuation-only query alone" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png?x=#{"%" * 2000}"
      raw = "[file](#{url})"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end

    it "takes a short URL with a query whole in a markdown link" do
      result = extract("[file](/uploads/short-url/21.png?v=2)")

      upload = buffer.uploads.first
      expect(upload).to include(original_markdown: "[file](/uploads/short-url/21.png?v=2)")
      expect(result).to eq(upload[:placeholder])
    end

    # A destination may end in a bare `?` or `#`; the engine keeps the
    # marker in the href, so the construct takes it as part of the URL.
    it "takes a short URL ending in a bare query marker whole" do
      result = extract("[file](/uploads/short-url/21.png?)")

      upload = buffer.uploads.first
      expect(upload).to include(original_markdown: "[file](/uploads/short-url/21.png?)")
      expect(result).to eq(upload[:placeholder])
      expect(extractor.engine_refusals).to be_empty
    end

    it "takes a full upload URL ending in a bare query marker whole" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png?"
      result = extract("[file](#{url})")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: "[file](#{url})")
      expect(result).to eq(upload[:placeholder])
      expect(extractor.engine_refusals).to be_empty
    end

    it "takes a full upload URL ending in a bare fragment marker whole" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png#"
      result = extract("[file](#{url})")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: "[file](#{url})")
      expect(result).to eq(upload[:placeholder])
      expect(extractor.engine_refusals).to be_empty
    end
  end

  describe "S3/CDN storage URLs without an uploads segment" do
    # Core's S3 store writes the `original|optimized/` path directly under
    # the bucket host or a bucket prefix, with no `/uploads/` segment.
    it "defers a bare absolute storage URL" do
      url = "https://cdn.example.com/original/1X/#{sha1}.png"
      result = extract("pic #{url} here")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: url)
      expect(result).to eq("pic #{upload[:placeholder]} here")
    end

    it "defers a protocol-relative bucket-prefixed storage URL in an image" do
      url = "//cdn.example.com/bucket/optimized/2X/a/#{sha1}_2_690x388.png"
      result = extract("![x](#{url})")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: "![x](#{url})")
      expect(result).to eq(upload[:placeholder])
    end

    it "leaves a relative storage path without an uploads segment alone" do
      # No local store writes a relative `/original/…` path; recognizing one
      # would rewrite unrelated site paths that happen to share the name.
      raw = "[x](/original/1X/#{sha1}.png)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end
  end
end
