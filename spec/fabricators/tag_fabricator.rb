# frozen_string_literal: true

Fabricator(:tag) { name { sequence(:name) { |i| "tag#{i + 1}" } } }
