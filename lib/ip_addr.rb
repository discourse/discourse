class IPAddr

  def to_cidr_s
    if @addr
      mask = @mask_addr.to_s(2).count('1')
      if mask == 32
        to_s
      else
        "#{to_s}/#{mask}"
      end
    else
      nil
    end
  end

end
