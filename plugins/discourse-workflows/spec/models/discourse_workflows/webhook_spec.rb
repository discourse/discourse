# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook do
  describe ".normalize_method" do
    it "uppercases the value" do
      expect(described_class.normalize_method("post")).to eq("POST")
    end

    it "stringifies non-string input" do
      expect(described_class.normalize_method(nil)).to eq("")
    end
  end

  describe ".normalize_path" do
    it "strips a single leading slash" do
      expect(described_class.normalize_path("/users/42")).to eq("users/42")
    end

    it "leaves a path without a leading slash unchanged" do
      expect(described_class.normalize_path("hooks/inbound")).to eq("hooks/inbound")
    end
  end

  describe ".segments_for" do
    it "splits on slashes and discards empties" do
      expect(described_class.segments_for("/users/42/posts/")).to eq(%w[users 42 posts])
    end
  end

  describe ".dynamic_path?" do
    it "is true when any segment is a :name placeholder" do
      expect(described_class.dynamic_path?("users/:id")).to be(true)
    end

    it "is false when every segment is literal" do
      expect(described_class.dynamic_path?("users/list")).to be(false)
    end
  end

  describe ".path_length_for" do
    it "counts segments including dynamic ones" do
      expect(described_class.path_length_for("users/:id/posts")).to eq(3)
    end
  end

  describe ".match_dynamic_path" do
    it "captures values for :name segments and returns them" do
      result = described_class.match_dynamic_path(template: "users/:id", segments: %w[users 42])
      expect(result).to eq("id" => "42")
    end

    it "returns nil when literal segments do not match" do
      result = described_class.match_dynamic_path(template: "posts/:id", segments: %w[users 42])
      expect(result).to be_nil
    end

    it "returns nil when segment counts differ" do
      result =
        described_class.match_dynamic_path(template: "users/:id", segments: %w[users 42 extra])
      expect(result).to be_nil
    end
  end
end
