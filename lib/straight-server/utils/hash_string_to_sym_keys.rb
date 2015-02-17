class Hash

  # Replace String keys in the current hash with symbol keys
  def keys_to_sym!
    new_hash = keys_to_sym
    self.clear
    new_hash.each do |k,v|
      self[k] = v
    end
  end

  def keys_to_sym
    symbolized_hash = {} 
    self.each do |k,v|
      if k =~ /\A[a-zA-Z0-9!?_]+\Z/
        symbolized_hash[k.to_sym] = v
      else
        symbolized_hash[k] = v
      end
    end
    symbolized_hash
  end

end
