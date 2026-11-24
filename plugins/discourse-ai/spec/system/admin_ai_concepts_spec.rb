# frozen_string_literal: true

describe "Admin AI concepts" do
  fab!(:admin)
  fab!(:vector_def, :cloudflare_embedding_def)

  fab!(:infrastructure) do
    Fabricate(
      :inferred_concept,
      name: "Infrastructure",
      description: "Cloud infrastructure, servers, and deployment platforms",
      status: :active,
    )
  end
  fab!(:kubernetes) do
    Fabricate(
      :inferred_concept,
      name: "Kubernetes",
      parent: infrastructure,
      description: "Container orchestration, clusters, and workloads",
      aliases: %w[k8s-cluster kube],
      status: :active,
    )
  end
  fab!(:helm) do
    Fabricate(
      :inferred_concept,
      name: "Helm",
      parent: kubernetes,
      description: "Package manager for Kubernetes charts",
      status: :candidate,
    )
  end
  fab!(:k8s_dup) do
    Fabricate(
      :inferred_concept,
      name: "k8s",
      description: "Short-form duplicate for Kubernetes",
      status: :candidate,
    )
  end
  fab!(:service_mesh) do
    Fabricate(
      :inferred_concept,
      name: "Service Mesh",
      description: "East-west traffic management and mTLS",
      aliases: ["istio"],
      status: :candidate,
    )
  end
  fab!(:legacy_vm) do
    Fabricate(
      :inferred_concept,
      name: "Legacy VM",
      description: "Retired virtual machine deployments",
      status: :retired,
    )
  end

  fab!(:k8s_topic) { Fabricate(:topic, title: "Deploying Discourse clusters on Kubernetes") }
  fab!(:helm_topic) { Fabricate(:topic, title: "Zero-downtime Helm rollouts in production") }
  fab!(:k8s_post) { Fabricate(:post, topic: k8s_topic) }

  before do
    enable_current_plugin
    SiteSetting.ai_embeddings_selected_model = vector_def.id
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.inferred_concepts_enabled = true

    InferredConceptTopic.create!(
      inferred_concept: kubernetes,
      topic: k8s_topic,
      relevance: 0.95,
      primary: true,
    )
    InferredConceptTopic.create!(
      inferred_concept: kubernetes,
      topic: helm_topic,
      relevance: 0.82,
      primary: false,
    )
    InferredConceptTopic.create!(
      inferred_concept: helm,
      topic: helm_topic,
      relevance: 0.91,
      primary: true,
    )
    InferredConceptPost.create!(
      inferred_concept: kubernetes,
      post: k8s_post,
      relevance: 0.88,
      primary: false,
    )

    sign_in(admin)
  end

  it "lists, inspects, and merges inferred concepts" do
    visit "/admin/plugins/discourse-ai/ai-concepts"

    expect(page).to have_css(".ai-concepts-list__table")
    expect(page).to have_css("[data-concept-id='#{kubernetes.id}']", text: "Kubernetes")
    expect(page).to have_css("[data-concept-id='#{kubernetes.id}']", text: "k8s-cluster")
    expect(page).to have_css("[data-concept-id='#{helm.id}']", text: "Helm")
    expect(page).to have_css("[data-concept-id='#{k8s_dup.id}']", text: "k8s")
    expect(page).to have_css("[data-concept-id='#{service_mesh.id}']", text: "Service Mesh")
    expect(page).to have_css("[data-concept-id='#{legacy_vm.id}']", text: "Legacy VM")

    find("[data-concept-id='#{kubernetes.id}'] .ai-concepts-list__edit-btn").click

    expect(page).to have_css(".ai-concept-editor__form")
    expect(
      PageObjects::Components::SelectKit.new(".ai-concept-editor__parent-chooser"),
    ).to have_selected_name("Infrastructure")
    expect(page).to have_css(".ai-concept-editor__children-card", text: "Helm")
    expect(page).to have_css(
      ".ai-concept-editor__topics-card",
      text: "Deploying Discourse clusters on Kubernetes",
    )

    find(".ai-concept-editor .back-button").click

    expect(page).to have_css(".ai-concepts-list__table")
    find("[data-concept-id='#{k8s_dup.id}'] .ai-concepts-list__actions-menu").click
    find(".ai-concepts-list__merge-btn").click

    expect(page).to have_css(".ai-concept-merge-modal")
    merge_target =
      PageObjects::Components::SelectKit.new(
        ".ai-concept-merge-modal .ai-concept-merge-modal__target-chooser",
      )
    merge_target.expand
    merge_target.search("Kubernetes")
    merge_target.select_row_by_name("Kubernetes")
    find(".ai-concept-merge-modal__submit").click

    expect(page).to have_no_css(".ai-concept-merge-modal")
    expect(page).to have_css(
      "[data-concept-id='#{k8s_dup.id}'] .ai-concept-status[data-status='retired']",
    )
    expect(k8s_dup.reload).to be_retired
    expect(kubernetes.reload.aliases).to include("k8s")
  end
end
