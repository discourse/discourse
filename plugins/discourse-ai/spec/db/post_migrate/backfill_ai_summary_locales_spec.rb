# frozen_string_literal: true

require Rails.root.join(
          "plugins/discourse-ai/db/post_migrate/20260721080420_backfill_ai_summary_locales.rb",
        )

RSpec.describe BackfillAiSummaryLocales do
  fab!(:localized_topic) { Fabricate(:topic, locale: "fr") }
  fab!(:locale_less_topic) { Fabricate(:topic, locale: nil) }

  before do
    @migration_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @migration_verbose }

  it "backfills locale-less topic summaries from the topic or default locale" do
    source_summary = Fabricate(:ai_summary, target: localized_topic, locale: nil)
    default_summary = Fabricate(:ai_summary, target: locale_less_topic, locale: nil)
    existing_localized_summary =
      Fabricate(
        :ai_summary,
        target: locale_less_topic,
        summary_type: AiSummary.summary_types[:gist],
        locale: "he",
      )

    described_class.new.up

    expect(source_summary.reload.locale).to eq("fr")
    expect(default_summary.reload.locale).to eq("en")
    expect(existing_localized_summary.reload.locale).to eq("he")
  end
end
