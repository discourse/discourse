# frozen_string_literal: true

describe DiscourseMcp::Tools::CreateCategory do
  fab!(:admin)
  let(:request_context) do
    instance_double(
      DiscourseMcp::RequestContext,
      content_policy: DiscourseMcp::ContentPolicy.new([]),
      guardian: admin.guardian,
    )
  end

  describe ".call" do
    it "stores canonical emoji names on creation and update" do
      result =
        described_class.call(arguments: { "name" => "Dogs", "emoji" => ":dog:" }, request_context:)
      category = Category.find(result[:structuredContent][:id])
      expect(category.emoji).to eq("dog")
      expect(category.style_type).to eq("emoji")

      result =
        DiscourseMcp::Tools::UpdateCategory.call(
          arguments: {
            "category_id" => category.id,
            "emoji" => " ::cat:: ",
          },
          request_context:,
        )
      expect(category.reload.emoji).to eq("cat")
      expect(result[:structuredContent][:category][:emoji]).to eq("cat")
    end

    it "rejects a shortcode with no emoji name" do
      expect do
        described_class.call(arguments: { "name" => "Dogs", "emoji" => " :: " }, request_context:)
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.category_emoji_required"))
      expect(Category.where(name: "Dogs")).not_to exist
    end

    it "rejects a blank emoji even when an icon is provided" do
      expect do
        described_class.call(
          arguments: {
            "name" => "Dogs",
            "emoji" => "::",
            "icon" => "dog",
          },
          request_context:,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.category_emoji_required"))
      expect(Category.where(name: "Dogs")).not_to exist
    end

    it "preserves the existing emoji when an update has no emoji name" do
      category = Fabricate(:category, emoji: "dog", style_type: "emoji")

      expect do
        DiscourseMcp::Tools::UpdateCategory.call(
          arguments: {
            "category_id" => category.id,
            "emoji" => "::",
          },
          request_context:,
        )
      end.to raise_error(DiscourseMcp::ToolError, I18n.t("mcp.errors.category_emoji_required"))

      expect(category.reload.emoji).to eq("dog")
      expect(category.style_type).to eq("emoji")
    end

    it "rejects unknown emoji names without creating a category" do
      expect do
        described_class.call(
          arguments: {
            "name" => "Dogs",
            "emoji" => ":nonexistent_mcp_emoji:",
          },
          request_context:,
        )
      end.to raise_error(DiscourseMcp::ToolError)
      expect(Category.where(name: "Dogs")).not_to exist
    end
  end
end
