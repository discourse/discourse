# frozen_string_literal: true

describe DiscourseMcp::ScopePresenter do
  describe ".sections" do
    it "separates scopes that administration or moderation tools need" do
      sections =
        described_class.sections(%w[mcp:site-settings:write mcp:content:read mcp:moderation:read])

      expect(sections.map(&:name)).to eq(%w[member manage])
      expect(sections.map { |section| section.items.map(&:scope) }).to eq(
        [%w[mcp:content:read], %w[mcp:site-settings:write mcp:moderation:read]],
      )
    end

    it "leaves out a section with nothing in it" do
      expect(described_class.sections(%w[mcp:profile:read]).map(&:name)).to eq(%w[member])
    end
  end

  describe ".items" do
    it "lists each area's read scope before its write scope, with other areas last" do
      scopes = %w[
        mcp:themes:write
        mcp:content:write
        other-plugin:write
        mcp:content:read
        mcp:themes:read
      ]

      expect(described_class.items(scopes).map(&:scope)).to eq(
        %w[mcp:content:read mcp:content:write mcp:themes:read mcp:themes:write other-plugin:write],
      )
    end
  end

  describe ".label" do
    it "describes every scope the server offers" do
      DiscourseMcp.registry.scopes.each do |scope|
        expect(described_class.label(scope)).to be_present, "#{scope} has no label"
      end
    end

    it "has no label for a scope nobody described" do
      expect(described_class.label("other-plugin:write")).to be_nil
    end
  end
end
