# frozen_string_literal: true

RSpec.describe Base62 do
  describe ".encode and .decode" do
    it "handles zero and negative numbers" do
      expect(Base62.encode(0)).to eq("0")
      expect(Base62.encode(-1)).to be_nil
      expect(Base62.encode(-999_999_999_999)).to be_nil
      expect(Base62.decode("")).to eq(0)
      expect(Base62.decode("0")).to eq(0)
    end

    it "round-trips single digits, Fixnum chunk boundaries, and 160-bit SHA1 integers" do
      samples = [
        1,
        61,
        62,
        63,
        (62**9) - 1,
        62**9,
        (62**9) + 1,
        (62**18) - 1,
        62**18,
        (62**18) + 42,
        "da39a3ee5e6b4b0d3255bfef95601890afd80709".to_i(16),
        ("f" * 40).to_i(16),
      ]

      samples.each do |n|
        encoded = Base62.encode(n)
        expect(encoded.encoding).to eq(Encoding::UTF_8)
        expect(Base62.decode(encoded)).to eq(n)
      end

      expect(Base62.encode("da39a3ee5e6b4b0d3255bfef95601890afd80709".to_i(16))).to eq(
        "v8vA6WnPVTOE1o39waNFVmAqEJj",
      )
    end

    it "preserves public constants and raises on invalid characters" do
      expect(Base62::BASE).to eq(62)
      expect(Base62::KEYS.length).to eq(62)
      expect(Base62::KEYS_HASH["Z"]).to eq(61)
      expect { Base62.decode("abc!def") }.to raise_error(NoMethodError)
      expect { Base62.decode("abcédef") }.to raise_error(NoMethodError)
    end
  end
end
