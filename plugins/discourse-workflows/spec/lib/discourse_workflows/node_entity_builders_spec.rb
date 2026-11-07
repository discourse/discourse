# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType do
  let(:node_source_globs) do
    %w[
      plugins/*/lib/discourse_workflows/**/*.rb
      plugins/*/lib/*/workflows/**/*.rb
      plugins/discourse-ai/discourse_workflows/**/*.rb
    ]
  end
  let(:builders_file) do
    "plugins/discourse-workflows/lib/discourse_workflows/entity_serializers.rb"
  end
  let(:banned_serializers) { /\b(BasicUserSerializer|TopicListItemSerializer)\b/ }
  let(:entity_names) do
    %w[
      user
      post
      topic
      group
      reviewable
      event
      badge
      tag
      channel
      message
      card
      board
      assignee
      assignment
      stats
      timer
      participation
      chat_message
    ]
  end
  let(:banned_entity_data_definitions) { /^\s*def\s+(self\.)?(#{entity_names.join("|")})_data\b/ }

  def node_source_paths
    node_source_globs
      .flat_map { |glob| Dir[Rails.root.join(glob)] }
      .uniq
      .map { |path| Pathname.new(path).relative_path_from(Rails.root).to_s }
  end

  it "builds users and topics through the NodeType helpers" do
    offenders =
      node_source_paths
        .reject { |path| path == builders_file }
        .select { |path| Rails.root.join(path).read.match?(banned_serializers) }

    expect(offenders).to be_empty
  end

  it "names entity builders serialize_<entity>" do
    offenders =
      node_source_paths.select do |path|
        Rails.root.join(path).read.match?(banned_entity_data_definitions)
      end

    expect(offenders).to be_empty
  end
end
