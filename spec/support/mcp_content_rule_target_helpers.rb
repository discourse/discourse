# frozen_string_literal: true

module McpContentRuleTargetHelpers
  def protect_targets(side, category_ids: [], tag_ids: [])
    McpContentRule.create!(
      rule_kind: "forum_content",
      config: {
        allow: {
          mode: side == :allow ? "selected" : "all",
          category_ids: side == :allow ? category_ids : [],
          tag_ids: side == :allow ? tag_ids : [],
        },
        deny: {
          category_ids: side == :deny ? category_ids : [],
          tag_ids: side == :deny ? tag_ids : [],
        },
      },
    )
  end

  def expect_rule_explanation(message)
    expect(message).to match(/content.*(?:rule|restrict)/i),
    "RULE EXPLANATION: expected an explanation that a content rule uses this target, got #{message.inspect}"
  end
end

RSpec.shared_context "with MCP content rule targets" do
  include McpContentRuleTargetHelpers

  fab!(:admin)

  before do
    McpContentRule.delete_all
    SiteSetting.tagging_enabled = true
    SiteSetting.max_category_nesting = 3
    Jobs.run_later!
  end
end
