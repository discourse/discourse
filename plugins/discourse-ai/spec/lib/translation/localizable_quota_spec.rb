# frozen_string_literal: true

describe DiscourseAi::Translation::LocalizableQuota do
  let(:test_class) do
    Class.new do
      include DiscourseAi::Translation::LocalizableQuota

      def self.model_name
        "post"
      end
    end
  end

  let(:model) { OpenStruct.new(id: 123) }
  let(:locale) { "en" }

  after { Discourse.redis.del(test_class.relocalize_key(model, locale)) }

  describe ".has_relocalize_quota?" do
    it "returns false if quota is at MAX_QUOTA_PER_DAY" do
      Discourse.redis.set(test_class.relocalize_key(model, locale), 2, ex: 10)
      expect(test_class.has_relocalize_quota?(model, locale)).to eq(false)
    end

    it "returns false if quota is above MAX_QUOTA_PER_DAY" do
      Discourse.redis.set(test_class.relocalize_key(model, locale), 3, ex: 10)
      expect(test_class.has_relocalize_quota?(model, locale)).to eq(false)
    end

    it "returns true if quota is below MAX_QUOTA_PER_DAY and increments quota" do
      Discourse.redis.set(test_class.relocalize_key(model, locale), 1, ex: 10)

      expect(test_class.has_relocalize_quota?(model, locale)).to eq(true)
      expect(Discourse.redis.get(test_class.relocalize_key(model, locale))).to eq("2")
    end

    it "does not increment quota if skip_incr is true" do
      Discourse.redis.set(test_class.relocalize_key(model, locale), 1, ex: 10)

      test_class.has_relocalize_quota?(model, locale, skip_incr: true)
      expect(Discourse.redis.get(test_class.relocalize_key(model, locale))).to eq("1")
    end

    it "initializes quota to 1 if not set before" do
      test_class.has_relocalize_quota?(model, locale)

      expect(Discourse.redis.get(test_class.relocalize_key(model, locale))).to eq("1")
    end

    it "sets expiry to 1 day when initializing quota" do
      test_class.has_relocalize_quota?(model, locale)

      ttl = Discourse.redis.ttl(test_class.relocalize_key(model, locale))
      expect(ttl).to be_within(5).of(1.day.to_i)
    end

    it "preserves TTL when incrementing existing quota" do
      Discourse.redis.set(test_class.relocalize_key(model, locale), 1, ex: 3600)
      original_ttl = Discourse.redis.ttl(test_class.relocalize_key(model, locale))

      test_class.has_relocalize_quota?(model, locale)

      new_ttl = Discourse.redis.ttl(test_class.relocalize_key(model, locale))
      expect(new_ttl).to be_within(2).of(original_ttl)
    end
  end
end
