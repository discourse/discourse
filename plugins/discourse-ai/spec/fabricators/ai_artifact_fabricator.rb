# frozen_string_literal: true
Fabricator(:ai_artifact, from: :web_artifact)

Fabricator(:ai_artifact_key_value, from: :web_artifact_key_value)

Fabricator(:ai_artifact_version, from: :web_artifact_version)
