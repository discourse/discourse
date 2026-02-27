# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSolved::CategoryType do
  fab!(:category)

  describe ".enable_plugin" do
    before { SiteSetting.solved_enabled = false }

    it "enables the solved plugin" do
      described_class.enable_plugin
      expect(SiteSetting.solved_enabled).to eq(true)
    end
  end

  describe ".configure_site_settings" do
    before do
      SiteSetting.show_filter_by_solved_status = false
      SiteSetting.notify_on_staff_accept_solved = false
      SiteSetting.empty_box_on_unsolved = false
    end

    it "enables sensible defaults for support categories" do
      described_class.configure_site_settings(category)

      expect(SiteSetting.show_filter_by_solved_status).to eq(true)
      expect(SiteSetting.notify_on_staff_accept_solved).to eq(true)
      expect(SiteSetting.empty_box_on_unsolved).to eq(true)
    end

    it "uses provided configuration_values over defaults" do
      described_class.configure_site_settings(
        category,
        configuration_values: {
          "show_filter_by_solved_status" => false,
          "empty_box_on_unsolved" => false,
        },
      )

      expect(SiteSetting.show_filter_by_solved_status).to eq(false)
      expect(SiteSetting.notify_on_staff_accept_solved).to eq(true)
      expect(SiteSetting.empty_box_on_unsolved).to eq(false)
    end
  end

  describe ".configure_category" do
    fab!(:admin)
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:reply) { Fabricate(:post, topic: topic, post_number: 2) }

    before do
      SiteSetting.solved_enabled = true
      DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
    end

    it "allows accepting answers on the category" do
      expect(Guardian.new(admin).can_accept_answer?(topic, reply)).to eq(false)

      described_class.configure_category(category)

      expect(Guardian.new(admin).can_accept_answer?(topic, reply)).to eq(true)
    end

    it "sets default auto-close hours" do
      described_class.configure_category(category)

      expect(category.custom_fields["solved_topics_auto_close_hours"]).to eq("48")
    end

    it "uses provided configuration_values for auto-close hours" do
      described_class.configure_category(
        category,
        configuration_values: {
          "solved_topics_auto_close_hours" => 72,
        },
      )

      expect(category.custom_fields["solved_topics_auto_close_hours"]).to eq("72")
    end
  end
end
