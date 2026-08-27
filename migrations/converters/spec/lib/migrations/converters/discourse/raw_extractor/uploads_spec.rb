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

    # The attachment marker folds case (core's split, see the detector), so an
    # upper-cased one still takes the attachment branch — with its size tail,
    # which the link-label branch has no reason to consume.
    it "reads an upper-cased attachment marker as an attachment, size included" do
      result = extract("[r.pdf|ATTACHMENT](upload://Zm9vYmFy.pdf) (1.2 MB)")

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
      expect(result).to eq(buffer.uploads.first[:placeholder])
    end

    # Core links a pipe-less `[label](upload://…)` too, but that shape is
    # unmeasured in real corpora, and widening the label grammar further is
    # where label-corruption risks live — so it deliberately stays verbatim,
    # reported on the must-resolve tally.
    it "leaves a pipe-less link label verbatim and reports it" do
      body = "[plain label](upload://Zm9vYmFy.png)"

      expect(extract(body)).to eq(body)
      expect(buffer.uploads).to be_empty
      expect(extractor.engine_refusals).to eq(unanchored: 1)
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
    # punctuation is a link once cooked — the detector defers it too.
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
end
