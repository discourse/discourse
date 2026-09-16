# frozen_string_literal: true

describe Jobs::GenerateAskAiReport do
  fab!(:admin)
  fab!(:llm_model)

  before do
    enable_current_plugin
    SiteSetting.ai_ask_ai_enabled = true
    allow(SiteSetting).to receive(:ai_default_llm_model).and_return(llm_model.id)
    freeze_time Time.utc(2026, 9, 9, 12)
  end

  def request_report(send_to_groups: false)
    DiscourseAi::AdminDashboard::AskAiReportRequest.call(
      user: admin,
      start_date: "2026-09-01",
      end_date: "2026-09-09",
      send_to_groups:,
    )
  end

  it "stores verified subjects and sends one PM even when the job runs twice" do
    ask = AskAiLog.create!(user: admin, query: "How do I configure email?", asked_at: Time.current)
    report = request_report
    output = {
      insights: [
        {
          title: "Email setup guidance",
          observation: "A question asks how to configure email.",
          suggested_action: "Review whether the email setup guide is easy to find.",
          ask_ids: [ask.id],
        },
      ],
      summary: "Users ask about email setup.",
      subjects: [{ name: "Email", description: "Setting up email delivery.", ask_ids: [ask.id] }],
    }

    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
      described_class.new.execute(report_id: report.id)
    end

    expect(report.reload).to be_report_status_completed
    expect(report.summary).to eq(output[:summary])
    expect(report.subjects.first).to have_attributes(name: "Email", ask_count: 1)
    expect(report.subjects.first.ask_ai_logs).to contain_exactly(ask)
    expect(report.topic.allowed_users).to include(admin)
    expect(report.topic.posts.count).to eq(1)
    expect(Nokogiri::HTML5.fragment(report.topic.first_post.cooked).text).to include(
      output[:summary],
      "Email",
      ask.query,
      output[:insights][0][:suggested_action],
    )
  end

  it "does not publish a result that arrives after the report expires" do
    ask = AskAiLog.create!(user: admin, query: "Question", asked_at: Time.current)
    report = request_report
    output = {
      "summary" => "Summary",
      "subjects" => [
        { "name" => "Questions", "description" => "Questions", "ask_ids" => [ask.id] },
      ],
      "insights" => [],
      "examples" => {
        ask.id => ask.query,
      },
    }
    generator = instance_double(DiscourseAi::AdminDashboard::AskAiReportGenerator)
    allow(DiscourseAi::AdminDashboard::AskAiReportGenerator).to receive(:new).and_return(generator)
    allow(generator).to receive(:generate) do
      freeze_time 31.minutes.from_now
      output
    end

    expect { described_class.new.execute(report_id: report.id) }.not_to change(Topic, :count)
    expect(report.reload).to be_report_status_failed
    expect(report.subjects).to be_empty
  end

  it "does not call the model for an expired queued report" do
    AskAiLog.create!(user: admin, query: "Question", asked_at: Time.current)
    report = request_report
    freeze_time 31.minutes.from_now
    allow(DiscourseAi::Completions::Llm).to receive(:proxy)

    described_class.new.execute(report_id: report.id)

    expect(report.reload).to be_report_status_failed
    expect(DiscourseAi::Completions::Llm).not_to have_received(:proxy)
  end

  it "fails without publishing when a selected ask was deleted before generation" do
    SiteSetting.ai_ask_ai_report_max_asks = 1
    AskAiLog.create!(user: admin, query: "Older question", asked_at: Time.current)
    selected = AskAiLog.create!(user: admin, query: "Selected question", asked_at: Time.current)
    report = request_report
    selected.destroy!

    described_class.new.execute(report_id: report.id)

    expect(report.reload).to be_report_status_failed
    expect(report.topic_id).to be_nil
    expect(report.subjects).to be_empty
  end

  it "fails without publishing when the model invents ask IDs" do
    ask = AskAiLog.create!(user: admin, query: "Email", asked_at: Time.current)
    report = request_report
    output = {
      insights: [],
      summary: "Email",
      subjects: [{ name: "Email", description: "Email questions", ask_ids: [ask.id + 1] }],
    }

    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
    end

    expect(report.reload).to be_report_status_failed
    expect(report.topic_id).to be_nil
    expect(report.subjects).to be_empty
  end

  it "keeps ungrouped questions without requesting a second analysis" do
    grouped = AskAiLog.create!(user: admin, query: "Email setup", asked_at: Time.current)
    ungrouped = AskAiLog.create!(user: admin, query: "猫", asked_at: Time.current)
    report = request_report
    output = {
      summary: "Email setup questions",
      subjects: [{ name: "Email", description: "Configuring email", ask_ids: [grouped.id] }],
      insights: [],
    }
    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
    end
    expect(report.reload).to be_report_status_completed
    expect(report.subjects.find_by!(name: "Email").ask_ai_logs).to contain_exactly(grouped)
    fallback = report.subjects.find_by!(name: "Ungrouped questions")
    expect(fallback.ask_ai_logs).to contain_exactly(ungrouped)
    expect(fallback.ask_count).to eq(1)
    expect(report.topic_id).to be_present
  end

  it "rejects duplicate assignments without requesting a corrected report" do
    ask = AskAiLog.create!(user: admin, query: "猫", asked_at: Time.current)
    report = request_report
    subject = { name: "Cats", description: "Cat questions", ask_ids: [ask.id] }
    invalid = {
      insights: [],
      summary: "Cats",
      subjects: [subject.merge(ask_ids: [ask.id, ask.id])],
    }
    corrected = { insights: [], summary: "Cats", subjects: [subject] }

    DiscourseAi::Completions::Llm.with_prepared_responses([invalid.to_json, corrected.to_json]) do
      described_class.new.execute(report_id: report.id)
    end

    expect(report.reload).to be_report_status_failed
    expect(report.subjects).to be_empty
    expect(report.topic_id).to be_nil
  end

  it "delivers to the admins group only when selected" do
    ask = AskAiLog.create!(user: admin, query: "Email", asked_at: Time.current)
    report = request_report(send_to_groups: true)
    output = {
      insights: [],
      summary: "Email",
      subjects: [{ name: "Email", description: "Email questions", ask_ids: [ask.id] }],
    }

    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
    end

    expect(report.reload).to be_report_status_completed
    expect(report.topic.allowed_groups.pluck(:name)).to eq(["admins"])
    expect(report.topic.allowed_users).to include(admin)
  end

  it "uses the configured groups when the job runs" do
    group = Fabricate(:group)
    SiteSetting.ai_ask_ai_report_recipient_groups = group.id.to_s
    ask = AskAiLog.create!(user: admin, query: "Email", asked_at: Time.current)
    report = request_report(send_to_groups: true)
    other_group = Fabricate(:group)
    SiteSetting.ai_ask_ai_report_recipient_groups = other_group.id.to_s
    output = {
      insights: [],
      summary: "Email",
      subjects: [{ name: "Email", description: "Email questions", ask_ids: [ask.id] }],
    }
    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
    end
    expect(report.reload).to be_report_status_completed
    expect(report.topic.allowed_groups).to contain_exactly(other_group)
    expect(report.topic.allowed_users).to include(admin)
    expect(report.topic_id).to be_present
  end

  it "allows overlapping subjects and uses the reporter model selected at generation time" do
    ask = AskAiLog.create!(user: admin, query: "Ask AI settings 猫", asked_at: Time.current)
    report = request_report
    model = Fabricate(:llm_model)
    agent = Fabricate(:ai_agent, enabled: false, default_llm_id: model.id)
    SiteSetting.ai_ask_ai_report_agent = agent.id
    allow(DiscourseAi::Completions::Llm).to receive(:proxy).and_call_original
    output = {
      insights: [],
      summary: "Configuration questions",
      subjects: [
        { name: "Ask AI", description: "Using Ask AI", ask_ids: [ask.id] },
        { name: "Admin settings", description: "Configuring the forum", ask_ids: [ask.id] },
      ],
    }
    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
    end
    expect(report.reload).to be_report_status_completed
    expect(report.reported_ask_count).to eq(1)
    expect(report.subjects.pluck(:ask_count)).to eq([1, 1])
    report.subjects.each { |subject| expect(subject.ask_ai_logs).to contain_exactly(ask) }
    expect(DiscourseAi::Completions::Llm).to have_received(:proxy).with(model)
    expect(report.topic.first_post.raw).to include("Questions can appear in multiple subjects.")
  end

  it "rejects insights that cite questions outside the report" do
    ask = AskAiLog.create!(user: admin, query: "Email", asked_at: Time.current)
    report = request_report
    output = {
      summary: "Email setup",
      subjects: [{ name: "Email", description: "Email setup", ask_ids: [ask.id] }],
      insights: [
        {
          title: "Email",
          observation: "Email setup",
          suggested_action: "Review the guide",
          ask_ids: [ask.id + 1],
        },
      ],
    }
    DiscourseAi::Completions::Llm.with_prepared_responses([output.to_json]) do
      described_class.new.execute(report_id: report.id)
    end
    expect(report.reload).to be_report_status_failed
    expect(report.topic_id).to be_nil
  end

  it "does not publish after the requester loses admin access" do
    AskAiLog.create!(user: admin, query: "Email", asked_at: Time.current)
    report = request_report
    admin.update!(admin: false)
    described_class.new.execute(report_id: report.id)
    expect(report.reload).to be_report_status_failed
    expect(report.topic_id).to be_nil
  end
end
