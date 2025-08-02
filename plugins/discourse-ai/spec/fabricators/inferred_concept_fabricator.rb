# frozen_string_literal: true
Fabricator(:inferred_concept) { name { sequence(:name) { |i| "concept_#{i}" } } }
