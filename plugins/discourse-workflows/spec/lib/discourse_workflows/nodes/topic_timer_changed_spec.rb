# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicTimerChanged::V1 do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:timer) { Fabricate(:topic_timer, topic: topic, user: admin) }

  let(:previous_attributes) do
    timer
      .attributes
      .slice(*TopicTimer::EVENT_ATTRIBUTES)
      .merge("status_type" => TopicTimer.types[:publish_to_category], "category_id" => category.id)
  end

  it "stays registered but hidden, with its change filter" do
    expect(described_class).not_to be_palette_visible
    expect(described_class.properties).to have_key(:changes)
    expect(DiscourseWorkflows::Registry.find_node_type(described_class.identifier)).to eq(
      described_class,
    )
  end

  it "splits into one palette trigger per change", :aggregate_failures do
    {
      "trigger:topic_timer_set" => %w[created updated],
      "trigger:topic_timer_cleared" => %w[cancelled],
      "trigger:topic_timer_completed" => %w[completed],
    }.each do |identifier, reasons|
      node_class = DiscourseWorkflows::Registry.find_node_type(identifier)

      expect(node_class).to be_palette_visible
      expect(node_class.i18n_scope).to eq("topic_timer_changed")
      expect(node_class.properties.keys).to include(:timer_types, :category_ids, :tag_names)
      expect(node_class.properties).not_to have_key(:changes)

      described_class::CHANGES.each do |change|
        expect(node_class.new(timer, change).valid?).to eq(reasons.include?(change))
      end
    end
  end

  it "ignores a stray change filter on the per-change triggers" do
    trigger = DiscourseWorkflows::Nodes::TopicTimerCleared::V1.new(timer, :cancelled)

    expect(trigger.matches?(trigger_context("changes" => ["created"]))).to eq(true)
  end

  it "leaves slow mode's end to the slow mode triggers, except on the hidden trigger",
     :aggregate_failures do
    slow_mode_end = Fabricate(:topic_timer, topic:, status_type: TopicTimer.types[:clear_slow_mode])
    set_trigger = DiscourseWorkflows::Nodes::TopicTimerSet::V1

    expect(set_trigger.new(slow_mode_end, :created)).not_to be_valid
    expect(described_class.new(slow_mode_end, :created)).to be_valid
    expect(set_trigger.properties.dig(:timer_types, :options)).not_to include("clear_slow_mode")
  end

  describe "#output" do
    it "describes the change, the timer and the timer it replaced on the set trigger" do
      node_class = DiscourseWorkflows::Nodes::TopicTimerSet::V1
      created = node_class.new(timer, :created, nil, acting_user: admin)
      updated = node_class.new(timer, :updated, previous_attributes, acting_user: admin)

      expect(created.output.keys).to eq(%i[topic actor change timer previous_timer])
      expect(created.output[:actor]).to include(id: admin.id)
      expect(created.output[:previous_timer]).to be_nil
      expect(updated.output[:previous_timer]).to include(
        status_type: "publish_to_category",
        category_id: category.id,
      )
      expect([created.output, updated.output]).to all(match_node_output_schema(node_class))
    end

    it "only describes the timer and the actor on the cleared and completed triggers" do
      {
        DiscourseWorkflows::Nodes::TopicTimerCleared::V1 => :cancelled,
        DiscourseWorkflows::Nodes::TopicTimerCompleted::V1 => :completed,
      }.each do |node_class, change|
        output = node_class.new(timer, change, nil, acting_user: admin).output

        expect(output.keys).to eq(%i[topic actor timer])
        expect(output[:timer]).to include(id: timer.id, status_type: "close")
        expect(output).to match_node_output_schema(node_class)
      end
    end

    it "adds the actor to the hidden trigger, null when the event carries none" do
      expect(described_class.new(timer, :cancelled, nil, acting_user: admin).output).to include(
        actor: include(id: admin.id),
      )

      output = described_class.new(timer, :created).output
      expect(output[:actor]).to be_nil
      expect(output).to match_node_output_schema(described_class)
    end

    it "builds from every shape the event fires with" do
      events =
        DiscourseEvent.track_events(:topic_timer_changed) do
          new_timer =
            Fabricate(:topic).set_or_create_timer(TopicTimer.types[:bump], 1, by_user: admin)
          new_timer.update!(execute_at: 2.hours.from_now)
          new_timer.finish!(:cancelled, by_user: admin)
        end

      outputs = events.map { |event| described_class.new(*event[:params]).output }
      expect(outputs.map { |output| output[:change] }).to eq(%w[created updated cancelled])
      expect(outputs.map { |output| output.dig(:actor, :id) }).to eq([admin.id] * 3)
      expect(outputs.second[:previous_timer]).to include(status_type: "bump")
    end
  end

  describe "#matches?" do
    it "matches the previous or current timer type" do
      trigger =
        DiscourseWorkflows::Nodes::TopicTimerSet::V1.new(timer, :updated, previous_attributes)

      expect(trigger.matches?(trigger_context("timer_types" => ["publish_to_category"]))).to eq(
        true,
      )
      expect(trigger.matches?(trigger_context("timer_types" => ["close"]))).to eq(true)
      expect(trigger.matches?(trigger_context("timer_types" => ["bump"]))).to eq(false)
    end

    it "keeps filtering the hidden trigger by change" do
      trigger = described_class.new(timer, :completed)

      expect(trigger.matches?(trigger_context("changes" => ["completed"]))).to eq(true)
      expect(trigger.matches?(trigger_context("changes" => ["cancelled"]))).to eq(false)
    end
  end
end
