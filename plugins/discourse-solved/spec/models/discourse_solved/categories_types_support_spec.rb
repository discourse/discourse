# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseSolved::Categories::Types::Support do
  fab!(:admin)
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
      described_class.configure_site_settings(category, guardian: admin.guardian)

      expect(SiteSetting.show_filter_by_solved_status).to eq(true)
    end

    it "uses provided configuration_values over defaults" do
      described_class.configure_site_settings(
        category,
        guardian: admin.guardian,
        configuration_values: {
          "show_filter_by_solved_status" => false,
        },
      )

      expect(SiteSetting.show_filter_by_solved_status).to eq(false)
    end
  end

  describe ".configure_category" do
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:reply) { Fabricate(:post, topic: topic, post_number: 2) }

    before do
      SiteSetting.solved_enabled = true
      DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
    end

    it "sets the enable_accepted_answers custom field to true" do
      described_class.configure_category(category, guardian: admin.guardian)
      expect(category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD]).to eq(
        "true",
      )
    end

    it "allows accepting answers on the category" do
      expect(Guardian.new(admin).can_accept_answer?(topic, reply)).to eq(false)

      described_class.configure_category(category, guardian: admin.guardian)

      expect(Guardian.new(admin).can_accept_answer?(topic, reply)).to eq(true)
    end

    it "sets default auto-close hours" do
      described_class.configure_category(category, guardian: admin.guardian)

      expect(category.custom_fields["solved_topics_auto_close_hours"]).to eq("48")
    end

    it "uses provided configuration_values for auto-close hours" do
      described_class.configure_category(
        category,
        guardian: admin.guardian,
        configuration_values: {
          "solved_topics_auto_close_hours" => 72,
        },
      )

      expect(category.custom_fields["solved_topics_auto_close_hours"]).to eq("72")
    end

    it "sets notify_on_staff_accept_solved custom field" do
      described_class.configure_category(category, guardian: admin.guardian)

      expect(
        category.custom_fields[DiscourseSolved::NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD],
      ).to eq("true")
    end

    it "sets empty_box_on_unsolved custom field" do
      described_class.configure_category(category, guardian: admin.guardian)

      expect(category.custom_fields[DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD]).to eq(
        "true",
      )
    end
  end

  describe ".find_matches" do
    fab!(:other_category, :category)

    before { described_class.configure_category(category, guardian: admin.guardian) }

    it "returns a relation for support categories" do
      matches = described_class.find_matches
      expect(matches).to be_a(ActiveRecord::Relation)
      expect(matches.to_a).to include(category)
      expect(matches.to_a).not_to include(other_category)
    end

    it "counts the support categories" do
      expect(Categories::TypeRegistry.counts[:support]).to eq(1)
    end
  end
end
