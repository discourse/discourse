# frozen_string_literal: true

RSpec.describe Onebox::Engine::LoomOnebox do
  it "returns the right HTML markup for the onebox" do
    expect(
      Onebox
        .preview(
          "https://www.loom.com/share/c9695e5dc084496c80b7d7516d2a569a?sid=e1279914-ecaa-4faf-afa8-89cbab488240",
        )
        .to_s
        .chomp,
    ).to eq(
      '<iframe class="loom-onebox" src="https://www.loom.com/embed/c9695e5dc084496c80b7d7516d2a569a?sid=e1279914-ecaa-4faf-afa8-89cbab488240" frameborder="0" allowfullscreen="" seamless="seamless" sandbox="allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-presentation"></iframe>',
    )
  end

  describe ".===" do
    it "matches valid Loom share URL" do
      valid_url = URI("https://www.loom.com/share/abc123")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Loom share URL with additional segment" do
      valid_url_with_segment = URI("https://www.loom.com/share/abc123/xyz456")
      expect(described_class === valid_url_with_segment).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://www.loom.com.malicious.com/share/abc123")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/share/abc123")
      expect(described_class === unrelated_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://www.loom.com/shares/abc123")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
