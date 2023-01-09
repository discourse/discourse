# frozen_string_literal: true

Fabricator(:tag_group) { name { sequence(:name) { |i| "tag_group_#{i}" } } }
